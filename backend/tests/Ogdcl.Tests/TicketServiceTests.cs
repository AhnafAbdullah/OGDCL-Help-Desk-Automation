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
        _service = new TicketService(_fx.Db, _fx.Notifier, new NullFileStorage());
    }

    public void Dispose() => _fx.Dispose();

    private Task<TicketDto> CreateTicket(int? categoryId = null) =>
        _service.CreateAsync(_fx.Employee.Id,
            new CreateTicketRequest(categoryId ?? _fx.ItCategory.Id, "Printer broken", "The 3rd floor printer is jammed."));

    [Fact]
    public async Task Create_AutoAssigns_ToHandlerInMappedDepartment_WithRulePriority()
    {
        var ticket = await CreateTicket();

        Assert.Equal(TicketStatus.Assigned, ticket.Status);
        Assert.Equal(TicketPriority.High, ticket.Priority); // from the IT rule
        Assert.Equal("IT", ticket.Department);
        Assert.Contains(ticket.AssignedTo, new[] { _fx.Handler1.DisplayName, _fx.Handler2.DisplayName });

        // The assigned handler is notified.
        var assignedName = ticket.AssignedTo;
        var handlerId = assignedName == _fx.Handler1.DisplayName ? _fx.Handler1.Id : _fx.Handler2.Id;
        Assert.Contains(_fx.Channel.Pushed, p =>
            p.UserId == handlerId && p.Notification.Type == NotificationType.TicketAssigned);
    }

    [Fact]
    public async Task Create_BalancesLoad_AcrossHandlers()
    {
        var first = await CreateTicket();
        var second = await CreateTicket();

        // With one open ticket each way, the two tickets must land on different handlers.
        Assert.NotEqual(first.AssignedTo, second.AssignedTo);
    }

    [Fact]
    public async Task Create_WithUnroutedCategory_StaysOpenAndUnassigned()
    {
        var ticket = await CreateTicket(_fx.UnroutedCategory.Id);

        Assert.Equal(TicketStatus.Open, ticket.Status);
        Assert.Null(ticket.AssignedTo);
    }

    [Fact]
    public async Task InvalidTransition_IsRejected()
    {
        var ticket = await CreateTicket();
        var handlerId = await AssignedHandlerId(ticket);

        // Assigned → Closed skips the workflow and must fail.
        await Assert.ThrowsAsync<AppValidationException>(() =>
            _service.UpdateStatusAsync(ticket.Id, handlerId, new UpdateTicketStatusRequest(TicketStatus.Closed, null)));
    }

    [Fact]
    public async Task NonAssignedHandler_CannotChangeStatus()
    {
        var ticket = await CreateTicket();
        var otherHandler = ticket.AssignedTo == _fx.Handler1.DisplayName ? _fx.Handler2 : _fx.Handler1;

        await Assert.ThrowsAsync<ForbiddenException>(() =>
            _service.UpdateStatusAsync(ticket.Id, otherHandler.Id,
                new UpdateTicketStatusRequest(TicketStatus.InProgress, null)));
    }

    [Fact]
    public async Task FullLifecycle_ResolvePromptsFeedback_CloseNotifiesBothParties()
    {
        var ticket = await CreateTicket();
        var handlerId = await AssignedHandlerId(ticket);

        await _service.UpdateStatusAsync(ticket.Id, handlerId, new UpdateTicketStatusRequest(TicketStatus.InProgress, "Working on it"));
        var resolved = await _service.UpdateStatusAsync(ticket.Id, handlerId, new UpdateTicketStatusRequest(TicketStatus.Resolved, "Fixed"));

        Assert.NotNull(resolved.ResolvedAt);
        Assert.Contains(_fx.Channel.Pushed, p =>
            p.UserId == _fx.Employee.Id && p.Notification.Type == NotificationType.FeedbackRequested);

        var closed = await _service.UpdateStatusAsync(ticket.Id, _fx.Employee.Id, new UpdateTicketStatusRequest(TicketStatus.Closed, null));
        Assert.NotNull(closed.ClosedAt);
        Assert.Contains(_fx.Channel.Pushed, p =>
            p.UserId == handlerId && p.Notification.Type == NotificationType.TicketClosed);

        // Status history recorded every step: created, in-progress, resolved, closed.
        Assert.Equal(4, closed.StatusHistory.Count);
    }

    [Fact]
    public async Task Feedback_RequiresResolvedTicket_AndOnlyOnce()
    {
        var ticket = await CreateTicket();
        var handlerId = await AssignedHandlerId(ticket);

        await Assert.ThrowsAsync<AppValidationException>(() =>
            _service.AddFeedbackAsync(ticket.Id, _fx.Employee.Id, new TicketFeedbackRequest(5, "Great")));

        await _service.UpdateStatusAsync(ticket.Id, handlerId, new UpdateTicketStatusRequest(TicketStatus.InProgress, null));
        await _service.UpdateStatusAsync(ticket.Id, handlerId, new UpdateTicketStatusRequest(TicketStatus.Resolved, null));

        var withFeedback = await _service.AddFeedbackAsync(ticket.Id, _fx.Employee.Id, new TicketFeedbackRequest(4, "Quick fix"));
        Assert.Equal(4, withFeedback.Feedback!.Rating);

        await Assert.ThrowsAsync<AppValidationException>(() =>
            _service.AddFeedbackAsync(ticket.Id, _fx.Employee.Id, new TicketFeedbackRequest(1, "Changed my mind")));
    }

    [Fact]
    public async Task Feedback_FromNonCreator_IsForbidden()
    {
        var ticket = await CreateTicket();
        var handlerId = await AssignedHandlerId(ticket);
        await _service.UpdateStatusAsync(ticket.Id, handlerId, new UpdateTicketStatusRequest(TicketStatus.InProgress, null));
        await _service.UpdateStatusAsync(ticket.Id, handlerId, new UpdateTicketStatusRequest(TicketStatus.Resolved, null));

        await Assert.ThrowsAsync<ForbiddenException>(() =>
            _service.AddFeedbackAsync(ticket.Id, handlerId, new TicketFeedbackRequest(5, null)));
    }

    private async Task<int> AssignedHandlerId(TicketDto ticket)
    {
        var full = await _service.GetByIdAsync(ticket.Id, _fx.Admin.Id);
        return full.AssignedTo == _fx.Handler1.DisplayName ? _fx.Handler1.Id : _fx.Handler2.Id;
    }
}
