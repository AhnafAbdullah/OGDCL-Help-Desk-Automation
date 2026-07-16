using Microsoft.EntityFrameworkCore;
using Ogdcl.Application.Common;
using Ogdcl.Application.Files;
using Ogdcl.Application.Notifications;
using Ogdcl.Domain;
using Ogdcl.Domain.Entities;

namespace Ogdcl.Application.Tickets;

public class TicketService
{
    private static readonly string[] AllowedAttachmentExtensions =
        [".jpg", ".jpeg", ".png", ".gif", ".pdf", ".docx", ".xlsx", ".txt"];

    // Statuses in which a complaint is actively waiting and therefore subject to
    // the anti-starvation escalation timer.
    private static readonly TicketStatus[] ActiveStatuses =
        [TicketStatus.Open, TicketStatus.Assigned, TicketStatus.InProgress];

    private readonly IAppDbContext _db;
    private readonly INotifier _notifier;
    private readonly IFileStorage _files;
    private readonly TimeProvider _time;
    private readonly EscalationOptions _escalation;

    public TicketService(IAppDbContext db, INotifier notifier, IFileStorage files,
        TimeProvider time, EscalationOptions escalation)
    {
        _db = db;
        _notifier = notifier;
        _files = files;
        _time = time;
        _escalation = escalation;
    }

    private DateTime Now => _time.GetUtcNow().UtcDateTime;

    // ----- categories -------------------------------------------------------
    public async Task<List<CategoryDto>> GetCategoriesAsync(CancellationToken ct = default) =>
        await _db.ComplaintCategories
            .Where(c => c.IsActive)
            .OrderBy(c => c.Name)
            .Select(c => new CategoryDto(c.Id, c.Name))
            .ToListAsync(ct);

    // ----- creation ---------------------------------------------------------
    public async Task<TicketDto> CreateAsync(int userId, CreateTicketRequest request, CancellationToken ct = default)
    {
        var actor = await GetActorAsync(userId, ct);
        if (actor.Role != UserRole.Employee)
            throw new ForbiddenException("Only employees can submit complaints. Admins must use an employee account to raise one.");

        if (string.IsNullOrWhiteSpace(request.Title))
            throw new AppValidationException("Title is required.");
        if (string.IsNullOrWhiteSpace(request.Description))
            throw new AppValidationException("Description is required.");
        if (request.Severity == TicketPriority.Critical)
            throw new AppValidationException("Critical is assigned automatically by escalation; choose Low, Medium, or Urgent.");

        var category = await _db.ComplaintCategories
            .FirstOrDefaultAsync(c => c.Id == request.CategoryId && c.IsActive, ct)
            ?? throw new AppValidationException("Unknown complaint category.");

        var rule = await _db.AssignmentRules.FirstOrDefaultAsync(r => r.CategoryId == category.Id, ct);

        var now = Now;
        var ticket = new Ticket
        {
            TicketNumber = await NextTicketNumberAsync(ct),
            Title = request.Title.Trim(),
            Description = request.Description.Trim(),
            CategoryId = category.Id,
            CreatedById = userId,
            DepartmentId = rule?.DepartmentId,
            Priority = request.Severity,
            // Urgent complaints must be approved by a floor/super admin before
            // handlers can see them; everything else is immediately open.
            Status = request.Severity == TicketPriority.Urgent ? TicketStatus.PendingApproval : TicketStatus.Open,
            CreatedAt = now,
            UpdatedAt = now,
        };
        ApplyEscalationTimer(ticket, now);

        ticket.StatusHistory.Add(new TicketStatusHistory
        {
            FromStatus = null,
            ToStatus = ticket.Status,
            ChangedById = userId,
            Note = "Complaint submitted",
            ChangedAt = now,
        });

        _db.Tickets.Add(ticket);
        await _db.SaveChangesAsync(ct);

        if (ticket.Status == TicketStatus.PendingApproval)
        {
            await _notifier.NotifyUsersAsync(await OversightIdsAsync(ticket.DepartmentId, ct),
                NotificationType.ApprovalRequired,
                $"Urgent complaint needs approval: {ticket.TicketNumber}",
                $"\"{ticket.Title}\" ({category.Name}) was raised as Urgent and needs your approval before it is opened to handlers.", ct);
        }
        else
        {
            await _notifier.NotifyUsersAsync(await DepartmentHandlerIdsAsync(ticket.DepartmentId, ct),
                NotificationType.NewComplaint,
                $"New complaint available: {ticket.TicketNumber}",
                $"\"{ticket.Title}\" ({category.Name}, {ticket.Priority}) is open for a handler to accept.", ct);
        }

        return await GetByIdAsync(ticket.Id, userId, ct);
    }

    // ----- urgent approval --------------------------------------------------
    public async Task<TicketDto> ApproveAsync(int ticketId, int actorId, CancellationToken ct = default)
    {
        var actor = await GetActorAsync(actorId, ct);
        var ticket = await LoadTicketAsync(ticketId, ct);
        EnsureCanApprove(actor, ticket);
        if (ticket.Status != TicketStatus.PendingApproval)
            throw new AppValidationException("This complaint is not awaiting approval.");

        var now = Now;
        Transition(ticket, TicketStatus.Open, actor.Id, "Urgent complaint approved", now);
        ApplyEscalationTimer(ticket, now);
        await _db.SaveChangesAsync(ct);

        await _notifier.NotifyUsersAsync([ticket.CreatedById], NotificationType.TicketStatusChanged,
            $"Complaint {ticket.TicketNumber} approved",
            $"Your urgent complaint \"{ticket.Title}\" was approved and is now with the {ticket.Department?.Name} team.", ct);
        await _notifier.NotifyUsersAsync(await DepartmentHandlerIdsAsync(ticket.DepartmentId, ct),
            NotificationType.NewComplaint,
            $"New urgent complaint: {ticket.TicketNumber}",
            $"\"{ticket.Title}\" (Urgent) is open for a handler to accept.", ct);

        return await GetByIdAsync(ticket.Id, actorId, ct);
    }

    public async Task<TicketDto> RejectApprovalAsync(int ticketId, int actorId, RejectRequest request, CancellationToken ct = default)
    {
        var actor = await GetActorAsync(actorId, ct);
        var ticket = await LoadTicketAsync(ticketId, ct);
        EnsureCanApprove(actor, ticket);
        if (ticket.Status != TicketStatus.PendingApproval)
            throw new AppValidationException("This complaint is not awaiting approval.");

        var now = Now;
        var note = string.IsNullOrWhiteSpace(request.Reason) ? "Urgent complaint declined" : $"Declined: {request.Reason.Trim()}";
        Transition(ticket, TicketStatus.Rejected, actor.Id, note, now);
        ticket.EscalationDueAt = null;
        await _db.SaveChangesAsync(ct);

        await _notifier.NotifyUsersAsync([ticket.CreatedById], NotificationType.TicketRejected,
            $"Complaint {ticket.TicketNumber} declined",
            $"Your urgent complaint \"{ticket.Title}\" was declined by {actor.DisplayName}. {(string.IsNullOrWhiteSpace(request.Reason) ? "" : "Reason: " + request.Reason.Trim())}", ct);

        return await GetByIdAsync(ticket.Id, actorId, ct);
    }

    // ----- handler accept / reject -----------------------------------------
    public async Task<TicketDto> AcceptAsync(int ticketId, int handlerId, CancellationToken ct = default)
    {
        var handler = await GetActorAsync(handlerId, ct);
        var ticket = await LoadTicketAsync(ticketId, ct);

        if (handler.Role != UserRole.Handler || handler.DepartmentId != ticket.DepartmentId)
            throw new ForbiddenException("Only handlers in the complaint's department can accept it.");
        if (ticket.Status != TicketStatus.Open)
            throw new AppValidationException("Only open complaints can be accepted.");

        var now = Now;
        ticket.AssignedToId = handler.Id;
        Transition(ticket, TicketStatus.Assigned, handler.Id, $"Accepted by {handler.DisplayName}", now);
        ApplyEscalationTimer(ticket, now);
        await _db.SaveChangesAsync(ct);

        await _notifier.NotifyUsersAsync([ticket.CreatedById], NotificationType.TicketAccepted,
            $"Complaint {ticket.TicketNumber} accepted",
            $"{handler.DisplayName} has taken up your complaint \"{ticket.Title}\".", ct);
        await _notifier.NotifyUsersAsync(await OversightIdsAsync(ticket.DepartmentId, ct),
            NotificationType.TicketAccepted,
            $"Complaint {ticket.TicketNumber} accepted",
            $"{handler.DisplayName} accepted \"{ticket.Title}\".", ct);

        return await GetByIdAsync(ticket.Id, handlerId, ct);
    }

    public async Task<TicketDto> RejectAsync(int ticketId, int handlerId, RejectRequest request, CancellationToken ct = default)
    {
        var handler = await GetActorAsync(handlerId, ct);
        var ticket = await LoadTicketAsync(ticketId, ct);

        if (handler.Role != UserRole.Handler || handler.DepartmentId != ticket.DepartmentId)
            throw new ForbiddenException("Only handlers in the complaint's department can reject it.");
        if (ticket.Status != TicketStatus.Open)
            throw new AppValidationException("Only open complaints can be rejected.");
        if (ticket.Rejections.Any(r => r.HandlerId == handler.Id))
            throw new AppValidationException("You have already passed on this complaint.");

        ticket.Rejections.Add(new TicketRejection
        {
            HandlerId = handler.Id,
            Reason = request.Reason?.Trim(),
            CreatedAt = Now,
        });
        await _db.SaveChangesAsync(ct);

        // If every handler in the department has now passed, flag the admins.
        var deptHandlers = await DepartmentHandlerIdsAsync(ticket.DepartmentId, ct);
        if (deptHandlers.Count > 0 && deptHandlers.All(id => ticket.Rejections.Any(r => r.HandlerId == id)))
        {
            await _notifier.NotifyUsersAsync(await OversightIdsAsync(ticket.DepartmentId, ct),
                NotificationType.System,
                $"All handlers passed on {ticket.TicketNumber}",
                $"Every handler in {ticket.Department?.Name} has declined \"{ticket.Title}\". It needs manual attention.", ct);
        }

        return await GetByIdAsync(ticket.Id, handlerId, ct);
    }

    // ----- status workflow --------------------------------------------------
    public async Task<TicketDto> UpdateStatusAsync(int ticketId, int actorId, UpdateTicketStatusRequest request, CancellationToken ct = default)
    {
        var actor = await GetActorAsync(actorId, ct);
        var ticket = await LoadTicketAsync(ticketId, ct);

        var from = ticket.Status;
        var to = request.Status;
        var isAdmin = IsAdmin(actor);
        var isAssignedHandler = ticket.AssignedToId == actor.Id;
        var isCreator = ticket.CreatedById == actor.Id;

        var permitted = (from, to) switch
        {
            (TicketStatus.Assigned, TicketStatus.InProgress) => isAssignedHandler || isAdmin,
            (TicketStatus.InProgress, TicketStatus.Resolved) => isAssignedHandler || isAdmin,
            (TicketStatus.Resolved, TicketStatus.Closed) => isCreator || isAssignedHandler || isAdmin,
            (TicketStatus.Resolved, TicketStatus.InProgress) => isCreator || isAdmin,
            _ => throw new AppValidationException($"A complaint cannot move from {from} to {to}."),
        };
        if (!permitted)
            throw new ForbiddenException("You are not allowed to make this status change.");

        var now = Now;
        Transition(ticket, to, actor.Id, request.Note, now);
        if (to == TicketStatus.Resolved) ticket.ResolvedAt = now;
        if (to == TicketStatus.Closed) ticket.ClosedAt = now;
        if (to == TicketStatus.InProgress) ticket.ResolvedAt = null;
        ApplyEscalationTimer(ticket, now);

        await _db.SaveChangesAsync(ct);
        await NotifyStatusChangeAsync(ticket, actor, from, to, ct);

        return await GetByIdAsync(ticket.Id, actorId, ct);
    }

    // ----- admin manual assignment override --------------------------------
    public async Task<TicketDto> AssignAsync(int ticketId, int actorId, AssignTicketRequest request, CancellationToken ct = default)
    {
        var actor = await GetActorAsync(actorId, ct);
        var ticket = await LoadTicketAsync(ticketId, ct);
        if (!IsAdmin(actor) || (actor.Role == UserRole.FloorAdmin && actor.DepartmentId != ticket.DepartmentId))
            throw new ForbiddenException("Only an admin for this department can assign it manually.");
        if (ticket.Status is TicketStatus.Closed or TicketStatus.Rejected or TicketStatus.PendingApproval)
            throw new AppValidationException($"A {ticket.Status} complaint cannot be assigned.");

        var handler = await _db.Users.FirstOrDefaultAsync(
            u => u.Id == request.HandlerId && u.Role == UserRole.Handler && u.IsActive, ct)
            ?? throw new AppValidationException("Handler not found or not active.");

        var now = Now;
        ticket.AssignedToId = handler.Id;
        if (ticket.Status == TicketStatus.Open)
            Transition(ticket, TicketStatus.Assigned, actor.Id, $"Manually assigned to {handler.DisplayName}", now);
        else
            ticket.UpdatedAt = now;
        ApplyEscalationTimer(ticket, now);

        await _db.SaveChangesAsync(ct);
        await _notifier.NotifyUsersAsync([handler.Id], NotificationType.TicketAssigned,
            $"Complaint {ticket.TicketNumber} assigned to you",
            $"\"{ticket.Title}\" was assigned to you by {actor.DisplayName}.", ct);

        return await GetByIdAsync(ticket.Id, actorId, ct);
    }

    // ----- feedback ---------------------------------------------------------
    public async Task<TicketDto> AddFeedbackAsync(int ticketId, int actorId, TicketFeedbackRequest request, CancellationToken ct = default)
    {
        if (request.Rating is < 1 or > 5)
            throw new AppValidationException("Rating must be between 1 and 5.");

        var ticket = await LoadTicketAsync(ticketId, ct);
        if (ticket.CreatedById != actorId)
            throw new ForbiddenException("Only the complaint's author can leave feedback.");
        if (ticket.Status is not (TicketStatus.Resolved or TicketStatus.Closed))
            throw new AppValidationException("Feedback can only be left after the complaint is resolved.");
        if (ticket.Feedback is not null)
            throw new AppValidationException("Feedback has already been submitted for this complaint.");

        ticket.Feedback = new TicketFeedback { TicketId = ticket.Id, Rating = request.Rating, Comment = request.Comment };
        await _db.SaveChangesAsync(ct);
        return await GetByIdAsync(ticket.Id, actorId, ct);
    }

    // ----- attachments ------------------------------------------------------
    public async Task<AttachmentDto> AddAttachmentAsync(
        int ticketId, int actorId, string fileName, string contentType, long sizeBytes, Stream content,
        CancellationToken ct = default)
    {
        var actor = await GetActorAsync(actorId, ct);
        var ticket = await LoadTicketAsync(ticketId, ct);

        if (ticket.CreatedById != actorId && !IsAdmin(actor))
            throw new ForbiddenException("Only the complaint's author can attach files.");
        if (ticket.Status is TicketStatus.Closed or TicketStatus.Rejected)
            throw new AppValidationException("Attachments cannot be added to a closed complaint.");

        var extension = Path.GetExtension(fileName).ToLowerInvariant();
        if (!AllowedAttachmentExtensions.Contains(extension))
            throw new AppValidationException($"File type '{extension}' is not allowed.");

        var storedPath = await _files.SaveAsync($"tickets/{ticket.Id}", fileName, content, ct);
        var attachment = new TicketAttachment
        {
            TicketId = ticket.Id,
            FileName = fileName,
            ContentType = contentType,
            SizeBytes = sizeBytes,
            StoredPath = storedPath,
            UploadedById = actorId,
        };
        _db.TicketAttachments.Add(attachment);
        await _db.SaveChangesAsync(ct);

        return new AttachmentDto(attachment.Id, attachment.FileName, attachment.ContentType, attachment.SizeBytes, attachment.UploadedAt);
    }

    public async Task<(TicketAttachment Meta, Stream Content)> GetAttachmentAsync(
        int ticketId, int attachmentId, int actorId, CancellationToken ct = default)
    {
        var actor = await GetActorAsync(actorId, ct);
        var ticket = await LoadTicketAsync(ticketId, ct);
        if (!CanView(ticket, actor))
            throw new ForbiddenException("You do not have access to this complaint.");

        var attachment = ticket.Attachments.FirstOrDefault(a => a.Id == attachmentId)
            ?? throw new NotFoundException("Attachment not found.");

        return (attachment, _files.OpenRead(attachment.StoredPath));
    }

    // ----- queries ----------------------------------------------------------
    public async Task<List<TicketSummaryDto>> GetMineAsync(int userId, CancellationToken ct = default) =>
        await SummaryQuery(_db.Tickets.Where(t => t.CreatedById == userId)).ToListAsync(ct);

    public async Task<List<TicketSummaryDto>> GetAssignedAsync(int handlerId, CancellationToken ct = default) =>
        await SummaryQuery(_db.Tickets.Where(t =>
            t.AssignedToId == handlerId && t.Status != TicketStatus.Closed && t.Status != TicketStatus.Rejected))
            .ToListAsync(ct);

    /// <summary>Open complaints in the handler's department they have not passed on.</summary>
    public async Task<List<TicketSummaryDto>> GetAvailableAsync(int handlerId, CancellationToken ct = default)
    {
        var handler = await GetActorAsync(handlerId, ct);
        if (handler.Role != UserRole.Handler || handler.DepartmentId is null)
            return [];
        return await SummaryQuery(_db.Tickets.Where(t =>
            t.Status == TicketStatus.Open
            && t.DepartmentId == handler.DepartmentId
            && !t.Rejections.Any(r => r.HandlerId == handlerId)))
            .ToListAsync(ct);
    }

    public async Task<List<TicketSummaryDto>> GetPendingApprovalsAsync(int actorId, CancellationToken ct = default)
    {
        var actor = await GetActorAsync(actorId, ct);
        if (!IsAdmin(actor))
            throw new ForbiddenException("Only admins can view approvals.");
        var query = _db.Tickets.Where(t => t.Status == TicketStatus.PendingApproval);
        if (actor.Role == UserRole.FloorAdmin)
            query = query.Where(t => t.DepartmentId == actor.DepartmentId);
        return await SummaryQuery(query).ToListAsync(ct);
    }

    public async Task<PagedResult<TicketSummaryDto>> SearchForAdminAsync(
        int actorId, TicketStatus? status, int? categoryId, int? departmentId, int page, int pageSize,
        CancellationToken ct = default)
    {
        var actor = await GetActorAsync(actorId, ct);
        if (!IsAdmin(actor))
            throw new ForbiddenException("Only admins can browse all complaints.");

        var query = _db.Tickets.AsQueryable();
        if (actor.Role == UserRole.FloorAdmin)
            query = query.Where(t => t.DepartmentId == actor.DepartmentId);
        else if (departmentId is not null)
            query = query.Where(t => t.DepartmentId == departmentId);
        if (status is not null) query = query.Where(t => t.Status == status);
        if (categoryId is not null) query = query.Where(t => t.CategoryId == categoryId);

        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);
        var total = await query.CountAsync(ct);
        var items = await SummaryQuery(query).Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
        return new PagedResult<TicketSummaryDto>(items, total, page, pageSize);
    }

    /// <summary>Per-handler throughput. Floor admins see only their department; super admins see all.</summary>
    public async Task<List<HandlerStatDto>> GetHandlerStatsAsync(int actorId, CancellationToken ct = default)
    {
        var actor = await GetActorAsync(actorId, ct);
        if (!IsAdmin(actor))
            throw new ForbiddenException("Only admins can view handler performance.");

        var handlers = _db.Users.Where(u => u.Role == UserRole.Handler);
        if (actor.Role == UserRole.FloorAdmin)
            handlers = handlers.Where(u => u.DepartmentId == actor.DepartmentId);

        return await handlers
            .OrderBy(u => u.DisplayName)
            .Select(u => new HandlerStatDto(
                u.Id,
                u.DisplayName,
                u.Department!.Name,
                _db.Tickets.Count(t => t.AssignedToId == u.Id && (t.Status == TicketStatus.Resolved || t.Status == TicketStatus.Closed)),
                _db.Tickets.Count(t => t.AssignedToId == u.Id && t.Status == TicketStatus.Closed),
                _db.Tickets.Count(t => t.AssignedToId == u.Id && (t.Status == TicketStatus.Assigned || t.Status == TicketStatus.InProgress))))
            .ToListAsync(ct);
    }

    public async Task<TicketDto> GetByIdAsync(int ticketId, int actorId, CancellationToken ct = default)
    {
        var actor = await GetActorAsync(actorId, ct);
        var ticket = await LoadTicketAsync(ticketId, ct);
        if (!CanView(ticket, actor))
            throw new ForbiddenException("You do not have access to this complaint.");

        // The recommended handler is advisory only (shown to handlers + admins);
        // the complaint is never auto-assigned to them.
        User? recommended = null;
        if (ticket.Status == TicketStatus.Open && (actor.Role == UserRole.Handler || IsAdmin(actor)))
            recommended = await RecommendHandlerAsync(ticket, ct);

        return ToDto(ticket, recommended);
    }

    // ----- anti-starvation escalation (called by the background worker) ------
    public async Task<int> EscalateDueTicketsAsync(CancellationToken ct = default)
    {
        var now = Now;
        var due = await _db.Tickets
            .Include(t => t.Category)
            .Include(t => t.Department)
            .Where(t => ActiveStatuses.Contains(t.Status) && t.EscalationDueAt != null && t.EscalationDueAt <= now)
            .ToListAsync(ct);

        foreach (var ticket in due)
        {
            var oldSeverity = ticket.Priority;
            var newSeverity = NextSeverity(oldSeverity);
            ticket.Priority = newSeverity;
            ticket.IsOverdue = true;
            ticket.EscalationCount++;
            ticket.UpdatedAt = now;
            ticket.EscalationDueAt = now.Add(_escalation.ThresholdFor(newSeverity));

            var note = newSeverity == oldSeverity
                ? $"Overdue reminder (severity already {newSeverity})"
                : $"Auto-escalated for running late: {oldSeverity} → {newSeverity}";
            ticket.StatusHistory.Add(new TicketStatusHistory
            {
                FromStatus = ticket.Status,
                ToStatus = ticket.Status,
                ChangedById = null, // system action
                Note = note,
                ChangedAt = now,
            });

            var recipients = (await OversightIdsAsync(ticket.DepartmentId, ct))
                .Concat(await DepartmentHandlerIdsAsync(ticket.DepartmentId, ct));
            if (ticket.AssignedToId is int assignee)
                recipients = recipients.Append(assignee);

            await _notifier.NotifyUsersAsync(recipients, NotificationType.TicketEscalated,
                $"⚠ Overdue: {ticket.TicketNumber} is now {newSeverity}",
                $"\"{ticket.Title}\" has been waiting too long and was escalated to {newSeverity}. Please act on it.", ct);
        }

        if (due.Count > 0)
            await _db.SaveChangesAsync(ct);
        return due.Count;
    }

    // ----- helpers ----------------------------------------------------------
    private static bool IsAdmin(User u) => u.Role is UserRole.FloorAdmin or UserRole.SuperAdmin;

    private static void EnsureCanApprove(User actor, Ticket ticket)
    {
        var canApprove = actor.Role == UserRole.SuperAdmin
            || (actor.Role == UserRole.FloorAdmin && actor.DepartmentId == ticket.DepartmentId);
        if (!canApprove)
            throw new ForbiddenException("Only a super admin or the department's floor admin can approve this.");
    }

    private static bool CanView(Ticket ticket, User actor) => actor.Role switch
    {
        UserRole.SuperAdmin => true,
        UserRole.FloorAdmin => ticket.DepartmentId == actor.DepartmentId,
        UserRole.Handler => ticket.AssignedToId == actor.Id || ticket.DepartmentId == actor.DepartmentId,
        _ => ticket.CreatedById == actor.Id,
    };

    private static TicketPriority NextSeverity(TicketPriority p) => p switch
    {
        TicketPriority.Low => TicketPriority.Medium,
        TicketPriority.Medium => TicketPriority.Urgent,
        TicketPriority.Urgent => TicketPriority.Critical,
        _ => TicketPriority.Critical,
    };

    private void ApplyEscalationTimer(Ticket ticket, DateTime now) =>
        ticket.EscalationDueAt = ActiveStatuses.Contains(ticket.Status)
            ? now.Add(_escalation.ThresholdFor(ticket.Priority))
            : null;

    private static void Transition(Ticket ticket, TicketStatus to, int? byUserId, string? note, DateTime now)
    {
        var from = ticket.Status;
        ticket.Status = to;
        ticket.UpdatedAt = now;
        ticket.StatusHistory.Add(new TicketStatusHistory
        {
            FromStatus = from,
            ToStatus = to,
            Note = note,
            ChangedById = byUserId,
            ChangedAt = now,
        });
    }

    private async Task<User?> RecommendHandlerAsync(Ticket ticket, CancellationToken ct)
    {
        if (ticket.DepartmentId is null)
            return null;
        var rejectedBy = ticket.Rejections.Select(r => r.HandlerId).ToList();
        return await _db.Users
            .Where(u => u.Role == UserRole.Handler && u.IsActive && u.DepartmentId == ticket.DepartmentId && !rejectedBy.Contains(u.Id))
            .Select(u => new
            {
                User = u,
                Open = _db.Tickets.Count(t => t.AssignedToId == u.Id && t.Status != TicketStatus.Closed && t.Status != TicketStatus.Rejected),
            })
            .OrderBy(x => x.Open).ThenBy(x => x.User.Id)
            .Select(x => x.User)
            .FirstOrDefaultAsync(ct);
    }

    private async Task<List<int>> DepartmentHandlerIdsAsync(int? departmentId, CancellationToken ct) =>
        departmentId is null ? []
        : await _db.Users.Where(u => u.Role == UserRole.Handler && u.IsActive && u.DepartmentId == departmentId)
            .Select(u => u.Id).ToListAsync(ct);

    /// <summary>Users who oversee a department: its floor admin(s) plus all super admins.</summary>
    private async Task<List<int>> OversightIdsAsync(int? departmentId, CancellationToken ct)
    {
        var superAdmins = await _db.Users.Where(u => u.Role == UserRole.SuperAdmin && u.IsActive)
            .Select(u => u.Id).ToListAsync(ct);
        if (departmentId is null)
            return superAdmins;
        var floorAdmins = await _db.Users
            .Where(u => u.Role == UserRole.FloorAdmin && u.IsActive && u.DepartmentId == departmentId)
            .Select(u => u.Id).ToListAsync(ct);
        return superAdmins.Concat(floorAdmins).Distinct().ToList();
    }

    private async Task NotifyStatusChangeAsync(Ticket ticket, User actor, TicketStatus from, TicketStatus to, CancellationToken ct)
    {
        if (to == TicketStatus.Closed)
        {
            var everyone = new List<int> { ticket.CreatedById };
            if (ticket.AssignedToId is int handler) everyone.Add(handler);
            await _notifier.NotifyUsersAsync(everyone, NotificationType.TicketClosed,
                $"Complaint {ticket.TicketNumber} closed",
                $"\"{ticket.Title}\" has been closed.", ct);
            return;
        }

        var others = new List<int>();
        if (ticket.CreatedById != actor.Id) others.Add(ticket.CreatedById);
        if (ticket.AssignedToId is int h && h != actor.Id) others.Add(h);
        await _notifier.NotifyUsersAsync(others, NotificationType.TicketStatusChanged,
            $"Complaint {ticket.TicketNumber}: {from} → {to}",
            $"\"{ticket.Title}\" was moved to {to} by {actor.DisplayName}.", ct);

        if (to == TicketStatus.Resolved)
            await _notifier.NotifyUsersAsync([ticket.CreatedById], NotificationType.FeedbackRequested,
                $"How was complaint {ticket.TicketNumber} handled?",
                "Your complaint has been resolved. Please rate how it was handled.", ct);
    }

    private async Task<string> NextTicketNumberAsync(CancellationToken ct)
    {
        var year = Now.Year;
        var countThisYear = await _db.Tickets.IgnoreQueryFilters().CountAsync(t => t.CreatedAt.Year == year, ct);
        return $"T-{year}-{countThisYear + 1:D4}";
    }

    private async Task<User> GetActorAsync(int userId, CancellationToken ct) =>
        await _db.Users.FirstOrDefaultAsync(u => u.Id == userId, ct)
        ?? throw new UnauthorizedException("Unknown user.");

    private async Task<Ticket> LoadTicketAsync(int ticketId, CancellationToken ct) =>
        await _db.Tickets
            .Include(t => t.Category)
            .Include(t => t.CreatedBy)
            .Include(t => t.AssignedTo)
            .Include(t => t.Department)
            .Include(t => t.Feedback)
            .Include(t => t.Attachments)
            .Include(t => t.Rejections)
            .Include(t => t.StatusHistory).ThenInclude(h => h.ChangedBy)
            .FirstOrDefaultAsync(t => t.Id == ticketId, ct)
        ?? throw new NotFoundException("Complaint not found.");

    private static IQueryable<TicketSummaryDto> SummaryQuery(IQueryable<Ticket> query) =>
        query
            .OrderByDescending(t => t.IsOverdue)
            .ThenByDescending(t => t.Priority)
            .ThenByDescending(t => t.UpdatedAt)
            .Select(t => new TicketSummaryDto(
                t.Id, t.TicketNumber, t.Title, t.Category.Name, t.Status, t.Priority, t.IsOverdue,
                t.CreatedBy.DisplayName,
                t.AssignedTo != null ? t.AssignedTo.DisplayName : null,
                t.Department != null ? t.Department.Name : null,
                t.CreatedAt, t.UpdatedAt));

    private static TicketDto ToDto(Ticket t, User? recommended) => new(
        t.Id, t.TicketNumber, t.Title, t.Description, t.Category.Name, t.Status, t.Priority, t.IsOverdue, t.EscalationDueAt,
        t.CreatedBy.DisplayName, t.CreatedById, t.AssignedTo?.DisplayName, t.AssignedToId,
        t.Department?.Name, t.DepartmentId,
        recommended?.DisplayName, recommended?.Id,
        t.CreatedAt, t.UpdatedAt, t.ResolvedAt, t.ClosedAt,
        t.Feedback is null ? null : new FeedbackDto(t.Feedback.Rating, t.Feedback.Comment, t.Feedback.CreatedAt),
        t.StatusHistory.OrderBy(h => h.ChangedAt).ThenBy(h => h.Id)
            .Select(h => new StatusHistoryDto(h.FromStatus, h.ToStatus, h.Note, h.ChangedBy != null ? h.ChangedBy.DisplayName : "System", h.ChangedAt))
            .ToList(),
        t.Attachments.Select(a => new AttachmentDto(a.Id, a.FileName, a.ContentType, a.SizeBytes, a.UploadedAt)).ToList());
}
