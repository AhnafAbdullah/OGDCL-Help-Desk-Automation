import '../../../domain/complaint.dart';
import '../../../domain/enums.dart';
import '../../../domain/user.dart';

/// Actions the complaint detail screen can offer. Kept 1:1 with what the
/// mock backend actually accepts — see the mirrored rules below. (Admin
/// actions — reassignment, approve/reject — don't appear here at all:
/// Admin is a web-dashboard-only role and never opens this app.)
enum ComplaintAction {
  selfAssign,
  startProgress,
  markResolved,
  closeComplaint,
  reopenComplaint,
  leaveFeedback,
  attachFile,
}

extension ComplaintActionLabel on ComplaintAction {
  String get label => switch (this) {
        ComplaintAction.selfAssign => 'Pick Up Complaint',
        ComplaintAction.startProgress => 'Start Progress',
        ComplaintAction.markResolved => 'Mark Resolved',
        ComplaintAction.closeComplaint => 'Close Complaint',
        ComplaintAction.reopenComplaint => 'Reopen Complaint',
        ComplaintAction.leaveFeedback => 'Leave Feedback',
        ComplaintAction.attachFile => 'Attach File',
      };
}

/// Mirrors the mock backend's transition rules (see `MockDatabase`), so the
/// UI never offers a button the backend would reject:
///  - Open -> Assigned: any Handler in the same department (self-assign).
///  - Assigned -> InProgress, InProgress -> Resolved, Resolved -> Closed:
///    only the handler the complaint is assigned to.
///  - Resolved -> Closed, Resolved -> InProgress (reopen): only the creator.
///  - PendingApproval and Rejected are terminal from the mobile app's point
///    of view — approval/rejection happens on the web dashboard.
List<ComplaintAction> availableActions(Complaint complaint, User actor) {
  final actions = <ComplaintAction>{};
  final isAssignedHandler = complaint.assignedToId == actor.id;
  final isCreator = complaint.createdById == actor.id;
  final isDepartmentHandler =
      actor.role == UserRole.handler && actor.department != null && actor.department == complaint.department;

  if (complaint.status == ComplaintStatus.open && isDepartmentHandler) {
    actions.add(ComplaintAction.selfAssign);
  }

  if (complaint.status == ComplaintStatus.assigned && isAssignedHandler) {
    actions.add(ComplaintAction.startProgress);
  }

  if (complaint.status == ComplaintStatus.inProgress && isAssignedHandler) {
    actions.add(ComplaintAction.markResolved);
  }

  if (complaint.status == ComplaintStatus.resolved) {
    if (isAssignedHandler) actions.add(ComplaintAction.closeComplaint);
    if (isCreator) {
      actions.add(ComplaintAction.closeComplaint);
      actions.add(ComplaintAction.reopenComplaint);
    }
  }

  if (isCreator &&
      (complaint.status == ComplaintStatus.resolved || complaint.status == ComplaintStatus.closed) &&
      complaint.feedback == null) {
    actions.add(ComplaintAction.leaveFeedback);
  }

  if (isCreator &&
      complaint.status != ComplaintStatus.closed &&
      complaint.status != ComplaintStatus.rejected) {
    actions.add(ComplaintAction.attachFile);
  }

  return actions.toList();
}
