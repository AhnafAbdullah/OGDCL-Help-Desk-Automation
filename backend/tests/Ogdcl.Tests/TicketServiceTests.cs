using Ogdcl.Application.Common;
using Ogdcl.Application.Tickets;
using Ogdcl.Domain;

namespace Ogdcl.Tests;

public class TicketServiceTests : IDisposable
{
    private readonly TestFixture _fx = new();
    private readonly TicketService _service;

    public TicketServiceTests()
    {
        _service = _fx.Tickets();
    }

    public void Dispose() => _fx.Dispose();

    private Task<TicketDto> Create(TicketPriority severity = TicketPriority.Medium, int? categoryId = null) =>
        _service.CreateAsync(_fx.Employee.Id,
            new CreateTicketRequest(categoryId ?? _fx.ItCategory.Id, "Printer broken", "The 3rd floor printer is jammed.", severity));

    // ----- creation & routing ----------------------------------------------
    [Fact]
    public async Task Create_NonUrgent_IsOpenUnassigned_AndNotifiesDeptHandlers()
    {
        var ticket = await Create(TicketPriority.Medium);

        Assert.Equal(TicketStatus.Open, ticket.Status);
        Assert.Null(ticket.AssignedTo);          // no auto-assignment
        Assert.Equal("IT", ticket.Department);
        Assert.Contains(_fx.Channel.Pushed, p =>
            (p.UserId == _fx.Handler1.Id || p.UserId == _fx.Handler2.Id)
            && p.Notification.Type == NotificationType.NewComplaint);
    }

    [Fact]
    public async Task Create_Urgent_IsPendingApproval_AndNotifiesAdmins()
    {
        var ticket = await Create(TicketPriority.Urgent);

        Assert.Equal(TicketStatus.PendingApproval, ticket.Status);
        Assert.Contains(_fx.Channel.Pushed, p =>
            p.UserId == _fx.ItFloorAdmin.Id && p.Notification.Type == NotificationType.ApprovalRequired);
        Assert.Contains(_fx.Channel.Pushed, p =>
            p.UserId == _fx.SuperAdmin.Id && p.Notification.Type == NotificationType.ApprovalRequired);
    }

    [Fact]
    public async Task Create_ByAdmin_IsForbidden()
    {
        await Assert.ThrowsAsync<ForbiddenException>(() =>
            _service.CreateAsync(_fx.SuperAdmin.Id,
                new CreateTicketRequest(_fx.ItCategory.Id, "x", "y", TicketPriority.Low)));
    }

    [Fact]
    public async Task Create_WithCriticalSeverity_IsRejected()
    {
        await Assert.ThrowsAsync<AppValidationException>(() => Create(TicketPriority.Critical));
    }

    // ----- urgent approval --------------------------------------------------
    [Fact]
    public async Task Approve_ByDeptFloorAdmin_OpensToHandlers()
    {
        var ticket = await Create(TicketPriority.Urgent);
        var approved = await _service.ApproveAsync(ticket.Id, _fx.ItFloorAdmin.Id);

        Assert.Equal(TicketStatus.Open, approved.Status);
        Assert.Contains(_fx.Channel.Pushed, p =>
            p.UserId == _fx.Employee.Id && p.Notification.Type == NotificationType.TicketStatusChanged);
    }

    [Fact]
    public async Task Approve_ByOtherDeptFloorAdmin_IsForbidden()
    {
        var ticket = await Create(TicketPriority.Urgent);
        await Assert.ThrowsAsync<ForbiddenException>(() =>
            _service.ApproveAsync(ticket.Id, _fx.HrFloorAdmin.Id)); // HR admin cannot approve an IT complaint
    }

    [Fact]
    public async Task Decline_Approval_MarksRejected_AndNotifiesAuthor()
    {
        var ticket = await Create(TicketPriority.Urgent);
        var declined = await _service.RejectApprovalAsync(ticket.Id, _fx.SuperAdmin.Id, new RejectRequest("Not urgent"));

        Assert.Equal(TicketStatus.Rejected, declined.Status);
        Assert.Contains(_fx.Channel.Pushed, p =>
            p.UserId == _fx.Employee.Id && p.Notification.Type == NotificationType.TicketRejected);
    }

    // ----- handler accept / reject -----------------------------------------
    [Fact]
    public async Task Accept_AssignsToHandler_AndCannotBeAcceptedTwice()
    {
        var ticket = await Create();
        var accepted = await _service.AcceptAsync(ticket.Id, _fx.Handler1.Id);

        Assert.Equal(TicketStatus.Assigned, accepted.Status);
        Assert.Equal(_fx.Handler1.DisplayName, accepted.AssignedTo);
        Assert.Contains(_fx.Channel.Pushed, p =>
            p.UserId == _fx.Employee.Id && p.Notification.Type == NotificationType.TicketAccepted);

        // A second handler can no longer accept it.
        await Assert.ThrowsAsync<AppValidationException>(() => _service.AcceptAsync(ticket.Id, _fx.Handler2.Id));
    }

    [Fact]
    public async Task Accept_ByHandlerInWrongDept_IsForbidden()
    {
        var ticket = await Create();
        await Assert.ThrowsAsync<ForbiddenException>(() => _service.AcceptAsync(ticket.Id, _fx.HrHandler.Id));
    }

    [Fact]
    public async Task Reject_KeepsOpen_AndRemovesFromThatHandlersAvailableList()
    {
        var ticket = await Create();
        var afterReject = await _service.RejectAsync(ticket.Id, _fx.Handler1.Id, new RejectRequest("busy"));
        Assert.Equal(TicketStatus.Open, afterReject.Status);

        var h1Available = await _service.GetAvailableAsync(_fx.Handler1.Id);
        var h2Available = await _service.GetAvailableAsync(_fx.Handler2.Id);
        Assert.DoesNotContain(h1Available, t => t.Id == ticket.Id); // hidden from the rejecter
        Assert.Contains(h2Available, t => t.Id == ticket.Id);       // still offered to others
    }

    [Fact]
    public async Task Recommendation_SuggestsLeastLoadedHandler_WithoutAssigning()
    {
        // Handler1 is busy with one accepted ticket; a new complaint should recommend Handler2.
        var busy = await Create();
        await _service.AcceptAsync(busy.Id, _fx.Handler1.Id);

        var fresh = await Create();
        var seenByAdmin = await _service.GetByIdAsync(fresh.Id, _fx.ItFloorAdmin.Id);

        Assert.Equal(_fx.Handler2.DisplayName, seenByAdmin.RecommendedHandler);
        Assert.Null(seenByAdmin.AssignedTo); // recommended, not assigned
    }

    // ----- lifecycle --------------------------------------------------------
    [Fact]
    public async Task FullLifecycle_AcceptWorkResolveCloseFeedback()
    {
        var ticket = await Create();
        await _service.AcceptAsync(ticket.Id, _fx.Handler1.Id);
        await _service.UpdateStatusAsync(ticket.Id, _fx.Handler1.Id, new UpdateTicketStatusRequest(TicketStatus.InProgress, null));
        var resolved = await _service.UpdateStatusAsync(ticket.Id, _fx.Handler1.Id, new UpdateTicketStatusRequest(TicketStatus.Resolved, "Fixed"));
        Assert.NotNull(resolved.ResolvedAt);
        Assert.Contains(_fx.Channel.Pushed, p =>
            p.UserId == _fx.Employee.Id && p.Notification.Type == NotificationType.FeedbackRequested);

        var closed = await _service.UpdateStatusAsync(ticket.Id, _fx.Employee.Id, new UpdateTicketStatusRequest(TicketStatus.Closed, null));
        Assert.Equal(TicketStatus.Closed, closed.Status);

        var withFeedback = await _service.AddFeedbackAsync(ticket.Id, _fx.Employee.Id, new TicketFeedbackRequest(5, "Great"));
        Assert.Equal(5, withFeedback.Feedback!.Rating);
    }

    [Fact]
    public async Task NonAssignedHandler_CannotProgressTicket()
    {
        var ticket = await Create();
        await _service.AcceptAsync(ticket.Id, _fx.Handler1.Id);
        await Assert.ThrowsAsync<ForbiddenException>(() =>
            _service.UpdateStatusAsync(ticket.Id, _fx.Handler2.Id, new UpdateTicketStatusRequest(TicketStatus.InProgress, null)));
    }

    // ----- anti-starvation escalation --------------------------------------
    [Fact]
    public async Task Escalation_OnTimeout_RaisesSeverity_FlagsOverdue_AndRestartsTimer()
    {
        var ticket = await Create(TicketPriority.Low);
        Assert.False(ticket.IsOverdue);

        // Past the Low threshold (10 min) → escalates to Medium and flags overdue.
        _fx.Time.Now = _fx.Time.Now.AddMinutes(11);
        Assert.Equal(1, await _service.EscalateDueTicketsAsync());
        var afterFirst = await _service.GetByIdAsync(ticket.Id, _fx.SuperAdmin.Id);
        Assert.Equal(TicketPriority.Medium, afterFirst.Severity);
        Assert.True(afterFirst.IsOverdue);

        // Timer restarted: not due again immediately.
        Assert.Equal(0, await _service.EscalateDueTicketsAsync());

        // Past Medium (6) → Urgent, then past Urgent (3) → Critical, then capped.
        _fx.Time.Now = _fx.Time.Now.AddMinutes(7);
        await _service.EscalateDueTicketsAsync();
        _fx.Time.Now = _fx.Time.Now.AddMinutes(4);
        await _service.EscalateDueTicketsAsync();
        var escalated = await _service.GetByIdAsync(ticket.Id, _fx.SuperAdmin.Id);
        Assert.Equal(TicketPriority.Critical, escalated.Severity);

        _fx.Time.Now = _fx.Time.Now.AddMinutes(4);
        await _service.EscalateDueTicketsAsync();
        var capped = await _service.GetByIdAsync(ticket.Id, _fx.SuperAdmin.Id);
        Assert.Equal(TicketPriority.Critical, capped.Severity); // never beyond Critical
    }

    [Fact]
    public async Task Escalation_IgnoresResolvedComplaints()
    {
        var ticket = await Create(TicketPriority.Low);
        await _service.AcceptAsync(ticket.Id, _fx.Handler1.Id);
        await _service.UpdateStatusAsync(ticket.Id, _fx.Handler1.Id, new UpdateTicketStatusRequest(TicketStatus.InProgress, null));
        await _service.UpdateStatusAsync(ticket.Id, _fx.Handler1.Id, new UpdateTicketStatusRequest(TicketStatus.Resolved, null));

        _fx.Time.Now = _fx.Time.Now.AddHours(2);
        Assert.Equal(0, await _service.EscalateDueTicketsAsync()); // resolved tickets are not escalated
    }

    // ----- handler performance stats ---------------------------------------
    [Fact]
    public async Task HandlerStats_AreScopedByAdminType()
    {
        // Super admin sees IT + HR handlers; a floor admin sees only their own.
        var superView = await _service.GetHandlerStatsAsync(_fx.SuperAdmin.Id);
        var itView = await _service.GetHandlerStatsAsync(_fx.ItFloorAdmin.Id);

        Assert.Contains(superView, s => s.HandlerId == _fx.HrHandler.Id);
        Assert.Contains(superView, s => s.HandlerId == _fx.Handler1.Id);
        Assert.All(itView, s => Assert.Equal("IT", s.Department));
        Assert.DoesNotContain(itView, s => s.HandlerId == _fx.HrHandler.Id);
    }

    [Fact]
    public async Task HandlerStats_CountResolvedAndClosed()
    {
        var ticket = await Create();
        await _service.AcceptAsync(ticket.Id, _fx.Handler1.Id);
        await _service.UpdateStatusAsync(ticket.Id, _fx.Handler1.Id, new UpdateTicketStatusRequest(TicketStatus.InProgress, null));
        await _service.UpdateStatusAsync(ticket.Id, _fx.Handler1.Id, new UpdateTicketStatusRequest(TicketStatus.Resolved, null));

        var stats = await _service.GetHandlerStatsAsync(_fx.ItFloorAdmin.Id);
        var h1 = stats.First(s => s.HandlerId == _fx.Handler1.Id);
        Assert.Equal(1, h1.Solved); // resolved counts as solved
    }
}
