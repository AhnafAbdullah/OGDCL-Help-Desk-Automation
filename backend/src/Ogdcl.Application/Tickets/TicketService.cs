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

    // Assigned is deliberately never a target here: tickets become Assigned only
    // through auto-assignment at creation or the admin assign endpoint.
    private static readonly Dictionary<TicketStatus, TicketStatus[]> AllowedTransitions = new()
    {
        [TicketStatus.Open] = [],
        [TicketStatus.Assigned] = [TicketStatus.InProgress],
        [TicketStatus.InProgress] = [TicketStatus.Resolved],
        [TicketStatus.Resolved] = [TicketStatus.Closed, TicketStatus.InProgress],
        [TicketStatus.Closed] = [],
    };

    private readonly IAppDbContext _db;
    private readonly INotifier _notifier;
    private readonly IFileStorage _files;

    public TicketService(IAppDbContext db, INotifier notifier, IFileStorage files)
    {
        _db = db;
        _notifier = notifier;
        _files = files;
    }

    public async Task<List<CategoryDto>> GetCategoriesAsync(CancellationToken ct = default) =>
        await _db.ComplaintCategories
            .Where(c => c.IsActive)
            .OrderBy(c => c.Name)
            .Select(c => new CategoryDto(c.Id, c.Name))
            .ToListAsync(ct);

    public async Task<TicketDto> CreateAsync(int userId, CreateTicketRequest request, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(request.Title))
            throw new AppValidationException("Title is required.");
        if (string.IsNullOrWhiteSpace(request.Description))
            throw new AppValidationException("Description is required.");

        var category = await _db.ComplaintCategories
            .FirstOrDefaultAsync(c => c.Id == request.CategoryId && c.IsActive, ct)
            ?? throw new AppValidationException("Unknown complaint category.");

        var rule = await _db.AssignmentRules
            .FirstOrDefaultAsync(r => r.CategoryId == category.Id, ct);

        var ticket = new Ticket
        {
            TicketNumber = await NextTicketNumberAsync(ct),
            Title = request.Title.Trim(),
            Description = request.Description.Trim(),
            CategoryId = category.Id,
            CreatedById = userId,
            Priority = rule?.DefaultPriority ?? TicketPriority.Medium,
            DepartmentId = rule?.DepartmentId,
        };

        // Auto-assignment: least-loaded active handler in the routed department.
        if (rule is not null)
        {
            var handler = await _db.Users
                .Where(u => u.Role == UserRole.Handler && u.IsActive && u.DepartmentId == rule.DepartmentId)
                .Select(u => new
                {
                    u.Id,
                    OpenCount = _db.Tickets.Count(t => t.AssignedToId == u.Id && t.Status != TicketStatus.Closed),
                })
                .OrderBy(x => x.OpenCount).ThenBy(x => x.Id)
                .FirstOrDefaultAsync(ct);

            if (handler is not null)
            {
                ticket.AssignedToId = handler.Id;
                ticket.Status = TicketStatus.Assigned;
            }
        }

        ticket.StatusHistory.Add(new TicketStatusHistory
        {
            FromStatus = null,
            ToStatus = ticket.Status,
            ChangedById = userId,
            Note = "Ticket created",
        });

        _db.Tickets.Add(ticket);
        await _db.SaveChangesAsync(ct);

        if (ticket.AssignedToId is int handlerId)
        {
            await _notifier.NotifyUsersAsync([handlerId], NotificationType.TicketAssigned,
                $"New ticket {ticket.TicketNumber}",
                $"\"{ticket.Title}\" ({category.Name}) has been assigned to you.", ct);
        }

        return await GetByIdAsync(ticket.Id, userId, ct);
    }

    public async Task<List<TicketSummaryDto>> GetMineAsync(int userId, CancellationToken ct = default) =>
        await SummaryQuery(_db.Tickets.Where(t => t.CreatedById == userId)).ToListAsync(ct);

    public async Task<List<TicketSummaryDto>> GetAssignedAsync(int handlerId, CancellationToken ct = default) =>
        await SummaryQuery(_db.Tickets.Where(t => t.AssignedToId == handlerId && t.Status != TicketStatus.Closed))
            .ToListAsync(ct);

    public async Task<PagedResult<TicketSummaryDto>> SearchAsync(
        TicketStatus? status, int? categoryId, int? departmentId, int page, int pageSize,
        CancellationToken ct = default)
    {
        var query = _db.Tickets.AsQueryable();
        if (status is not null) query = query.Where(t => t.Status == status);
        if (categoryId is not null) query = query.Where(t => t.CategoryId == categoryId);
        if (departmentId is not null) query = query.Where(t => t.DepartmentId == departmentId);

        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);

        var total = await query.CountAsync(ct);
        var items = await SummaryQuery(query).Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
        return new PagedResult<TicketSummaryDto>(items, total, page, pageSize);
    }

    public async Task<TicketDto> GetByIdAsync(int ticketId, int actorId, CancellationToken ct = default)
    {
        var actor = await GetActorAsync(actorId, ct);
        var ticket = await LoadTicketAsync(ticketId, ct);

        if (!CanView(ticket, actor))
            throw new ForbiddenException("You do not have access to this ticket.");

        return ToDto(ticket);
    }

    public async Task<TicketDto> UpdateStatusAsync(int ticketId, int actorId, UpdateTicketStatusRequest request, CancellationToken ct = default)
    {
        var actor = await GetActorAsync(actorId, ct);
        var ticket = await LoadTicketAsync(ticketId, ct);

        var from = ticket.Status;
        var to = request.Status;

        if (!AllowedTransitions.TryGetValue(from, out var targets) || !targets.Contains(to))
            throw new AppValidationException($"A ticket cannot move from {from} to {to}.");

        var isAdmin = actor.Role == UserRole.Admin;
        var isAssignedHandler = ticket.AssignedToId == actor.Id;
        var isCreator = ticket.CreatedById == actor.Id;

        var permitted = isAdmin
            || (isAssignedHandler && (from, to) is
                (TicketStatus.Assigned, TicketStatus.InProgress) or
                (TicketStatus.InProgress, TicketStatus.Resolved) or
                (TicketStatus.Resolved, TicketStatus.Closed))
            || (isCreator && (from, to) is
                (TicketStatus.Resolved, TicketStatus.Closed) or
                (TicketStatus.Resolved, TicketStatus.InProgress));

        if (!permitted)
            throw new ForbiddenException("You are not allowed to make this status change.");

        ticket.Status = to;
        ticket.UpdatedAt = DateTime.UtcNow;
        if (to == TicketStatus.Resolved) ticket.ResolvedAt = DateTime.UtcNow;
        if (to == TicketStatus.Closed) ticket.ClosedAt = DateTime.UtcNow;
        if (to == TicketStatus.InProgress) ticket.ResolvedAt = null;

        ticket.StatusHistory.Add(new TicketStatusHistory
        {
            FromStatus = from,
            ToStatus = to,
            Note = request.Note,
            ChangedById = actor.Id,
        });

        await _db.SaveChangesAsync(ct);
        await NotifyStatusChangeAsync(ticket, actor, from, to, ct);

        return await GetByIdAsync(ticket.Id, actorId, ct);
    }

    public async Task<TicketDto> AssignAsync(int ticketId, int actorId, AssignTicketRequest request, CancellationToken ct = default)
    {
        var actor = await GetActorAsync(actorId, ct);
        if (actor.Role != UserRole.Admin)
            throw new ForbiddenException("Only admins can assign tickets manually.");

        var ticket = await LoadTicketAsync(ticketId, ct);
        if (ticket.Status is TicketStatus.Closed)
            throw new AppValidationException("Closed tickets cannot be reassigned.");

        var handler = await _db.Users.FirstOrDefaultAsync(
            u => u.Id == request.HandlerId && u.Role == UserRole.Handler && u.IsActive, ct)
            ?? throw new AppValidationException("Handler not found or not active.");

        var from = ticket.Status;
        ticket.AssignedToId = handler.Id;
        ticket.DepartmentId = handler.DepartmentId ?? ticket.DepartmentId;
        if (ticket.Status == TicketStatus.Open)
            ticket.Status = TicketStatus.Assigned;
        ticket.UpdatedAt = DateTime.UtcNow;

        ticket.StatusHistory.Add(new TicketStatusHistory
        {
            FromStatus = from,
            ToStatus = ticket.Status,
            Note = $"Manually assigned to {handler.DisplayName}",
            ChangedById = actor.Id,
        });

        await _db.SaveChangesAsync(ct);
        await _notifier.NotifyUsersAsync([handler.Id], NotificationType.TicketAssigned,
            $"Ticket {ticket.TicketNumber} assigned to you",
            $"\"{ticket.Title}\" has been assigned to you by {actor.DisplayName}.", ct);

        return await GetByIdAsync(ticket.Id, actorId, ct);
    }

    public async Task<TicketDto> AddFeedbackAsync(int ticketId, int actorId, TicketFeedbackRequest request, CancellationToken ct = default)
    {
        if (request.Rating is < 1 or > 5)
            throw new AppValidationException("Rating must be between 1 and 5.");

        var ticket = await LoadTicketAsync(ticketId, ct);
        if (ticket.CreatedById != actorId)
            throw new ForbiddenException("Only the ticket creator can leave feedback.");
        if (ticket.Status is not (TicketStatus.Resolved or TicketStatus.Closed))
            throw new AppValidationException("Feedback can only be left after the ticket is resolved.");
        if (ticket.Feedback is not null)
            throw new AppValidationException("Feedback has already been submitted for this ticket.");

        ticket.Feedback = new TicketFeedback
        {
            TicketId = ticket.Id,
            Rating = request.Rating,
            Comment = request.Comment,
        };
        await _db.SaveChangesAsync(ct);
        return await GetByIdAsync(ticket.Id, actorId, ct);
    }

    public async Task<AttachmentDto> AddAttachmentAsync(
        int ticketId, int actorId, string fileName, string contentType, long sizeBytes, Stream content,
        CancellationToken ct = default)
    {
        var actor = await GetActorAsync(actorId, ct);
        var ticket = await LoadTicketAsync(ticketId, ct);

        if (ticket.CreatedById != actorId && actor.Role != UserRole.Admin)
            throw new ForbiddenException("Only the ticket creator can attach files.");
        if (ticket.Status == TicketStatus.Closed)
            throw new AppValidationException("Attachments cannot be added to a closed ticket.");

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

        return new AttachmentDto(attachment.Id, attachment.FileName, attachment.ContentType,
            attachment.SizeBytes, attachment.UploadedAt);
    }

    public async Task<(TicketAttachment Meta, Stream Content)> GetAttachmentAsync(
        int ticketId, int attachmentId, int actorId, CancellationToken ct = default)
    {
        var actor = await GetActorAsync(actorId, ct);
        var ticket = await LoadTicketAsync(ticketId, ct);
        if (!CanView(ticket, actor))
            throw new ForbiddenException("You do not have access to this ticket.");

        var attachment = ticket.Attachments.FirstOrDefault(a => a.Id == attachmentId)
            ?? throw new NotFoundException("Attachment not found.");

        return (attachment, _files.OpenRead(attachment.StoredPath));
    }

    private async Task NotifyStatusChangeAsync(Ticket ticket, User actor, TicketStatus from, TicketStatus to, CancellationToken ct)
    {
        var others = new List<int>();
        if (ticket.CreatedById != actor.Id) others.Add(ticket.CreatedById);
        if (ticket.AssignedToId is int h && h != actor.Id) others.Add(h);

        if (to == TicketStatus.Closed)
        {
            var everyone = new List<int> { ticket.CreatedById };
            if (ticket.AssignedToId is int handler) everyone.Add(handler);
            await _notifier.NotifyUsersAsync(everyone, NotificationType.TicketClosed,
                $"Ticket {ticket.TicketNumber} closed",
                $"\"{ticket.Title}\" has been closed.", ct);
            return;
        }

        await _notifier.NotifyUsersAsync(others, NotificationType.TicketStatusChanged,
            $"Ticket {ticket.TicketNumber}: {from} → {to}",
            $"\"{ticket.Title}\" was moved to {to} by {actor.DisplayName}.", ct);

        if (to == TicketStatus.Resolved)
        {
            await _notifier.NotifyUsersAsync([ticket.CreatedById], NotificationType.FeedbackRequested,
                $"How was ticket {ticket.TicketNumber} handled?",
                "Your complaint has been resolved. Please rate how it was handled.", ct);
        }
    }

    private static bool CanView(Ticket ticket, User actor) =>
        actor.Role == UserRole.Admin
        || ticket.CreatedById == actor.Id
        || ticket.AssignedToId == actor.Id;

    private async Task<string> NextTicketNumberAsync(CancellationToken ct)
    {
        var year = DateTime.UtcNow.Year;
        var countThisYear = await _db.Tickets
            .IgnoreQueryFilters()
            .CountAsync(t => t.CreatedAt.Year == year, ct);
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
            .Include(t => t.StatusHistory).ThenInclude(h => h.ChangedBy)
            .FirstOrDefaultAsync(t => t.Id == ticketId, ct)
        ?? throw new NotFoundException("Ticket not found.");

    private static IQueryable<TicketSummaryDto> SummaryQuery(IQueryable<Ticket> query) =>
        query
            .OrderByDescending(t => t.UpdatedAt)
            .Select(t => new TicketSummaryDto(
                t.Id, t.TicketNumber, t.Title, t.Category.Name, t.Status, t.Priority,
                t.CreatedBy.DisplayName,
                t.AssignedTo != null ? t.AssignedTo.DisplayName : null,
                t.CreatedAt, t.UpdatedAt));

    private static TicketDto ToDto(Ticket t) => new(
        t.Id, t.TicketNumber, t.Title, t.Description, t.Category.Name, t.Status, t.Priority,
        t.CreatedBy.DisplayName, t.CreatedById, t.AssignedTo?.DisplayName, t.AssignedToId, t.Department?.Name,
        t.CreatedAt, t.UpdatedAt, t.ResolvedAt, t.ClosedAt,
        t.Feedback is null ? null : new FeedbackDto(t.Feedback.Rating, t.Feedback.Comment, t.Feedback.CreatedAt),
        t.StatusHistory.OrderBy(h => h.ChangedAt).ThenBy(h => h.Id)
            .Select(h => new StatusHistoryDto(h.FromStatus, h.ToStatus, h.Note, h.ChangedBy.DisplayName, h.ChangedAt))
            .ToList(),
        t.Attachments.Select(a => new AttachmentDto(a.Id, a.FileName, a.ContentType, a.SizeBytes, a.UploadedAt))
            .ToList());
}
