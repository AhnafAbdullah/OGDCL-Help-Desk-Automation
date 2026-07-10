import '../../../domain/enums.dart';
import '../../../domain/ticket.dart';
import '../../../domain/user.dart';

/// Actions the ticket detail screen can offer. Kept 1:1 with what the
/// backend will actually accept — see the mirrored rules below.
enum TicketAction { startProgress, markResolved, closeTicket, reopenTicket, reassign, leaveFeedback, attachFile }

extension TicketActionLabel on TicketAction {
  String get label => switch (this) {
        TicketAction.startProgress => 'Start Progress',
        TicketAction.markResolved => 'Mark Resolved',
        TicketAction.closeTicket => 'Close Ticket',
        TicketAction.reopenTicket => 'Reopen Ticket',
        TicketAction.reassign => 'Reassign',
        TicketAction.leaveFeedback => 'Leave Feedback',
        TicketAction.attachFile => 'Attach File',
      };
}

/// Mirrors `TicketService.AllowedTransitions` plus the per-role checks in
/// `UpdateStatusAsync` / `AssignAsync` / `AddFeedbackAsync` /
/// `AddAttachmentAsync` on the backend, so the UI never offers a button the
/// server would reject.
List<TicketAction> availableActions(Ticket ticket, User actor) {
  final actions = <TicketAction>{};
  final isAdmin = actor.role == UserRole.admin;
  final isAssignedHandler = ticket.assignedToId == actor.id;
  final isCreator = ticket.createdById == actor.id;

  if (ticket.status == TicketStatus.assigned && (isAdmin || isAssignedHandler)) {
    actions.add(TicketAction.startProgress);
  }

  if (ticket.status == TicketStatus.inProgress && (isAdmin || isAssignedHandler)) {
    actions.add(TicketAction.markResolved);
  }

  if (ticket.status == TicketStatus.resolved) {
    if (isAdmin || isAssignedHandler) actions.add(TicketAction.closeTicket);
    if (isCreator) {
      actions.add(TicketAction.closeTicket);
      actions.add(TicketAction.reopenTicket);
    }
  }

  if (isAdmin && ticket.status != TicketStatus.closed) {
    actions.add(TicketAction.reassign);
  }

  if (isCreator &&
      (ticket.status == TicketStatus.resolved || ticket.status == TicketStatus.closed) &&
      ticket.feedback == null) {
    actions.add(TicketAction.leaveFeedback);
  }

  if ((isCreator || isAdmin) && ticket.status != TicketStatus.closed) {
    actions.add(TicketAction.attachFile);
  }

  return actions.toList();
}
