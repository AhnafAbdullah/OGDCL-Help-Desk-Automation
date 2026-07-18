import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

enum UserRole {
  employee,
  handler,
  security,
  admin;

  static UserRole fromJson(String value) => switch (value) {
        'Employee' => UserRole.employee,
        'Handler' => UserRole.handler,
        'Security' => UserRole.security,
        'Admin' => UserRole.admin,
        _ => throw ArgumentError('Unknown UserRole: $value'),
      };

  String get label => switch (this) {
        UserRole.employee => 'Employee',
        UserRole.handler => 'Handler',
        UserRole.security => 'Security',
        UserRole.admin => 'Admin',
      };
}

/// Mirrors the real backend's `TicketStatus` (Open/Assigned/InProgress/
/// Resolved/Closed) plus two mobile-app-only states used by the severity
/// approval workflow: [pendingApproval] (a Critical complaint awaiting
/// admin sign-off — approval itself happens on the web dashboard, since
/// Admin does not use this app) and [rejected] (the admin declined it on
/// the web dashboard). A real backend that doesn't yet know about the
/// approval workflow will never send these two, so they only ever occur
/// against the mock backend.
enum ComplaintStatus {
  pendingApproval,
  open,
  assigned,
  inProgress,
  resolved,
  closed,
  rejected;

  static ComplaintStatus fromJson(String value) => switch (value) {
        'Open' => ComplaintStatus.open,
        'Assigned' => ComplaintStatus.assigned,
        'InProgress' => ComplaintStatus.inProgress,
        'Resolved' => ComplaintStatus.resolved,
        'Closed' => ComplaintStatus.closed,
        'PendingApproval' => ComplaintStatus.pendingApproval,
        'Rejected' => ComplaintStatus.rejected,
        _ => throw ArgumentError('Unknown ComplaintStatus: $value'),
      };

  String toJson() => switch (this) {
        ComplaintStatus.pendingApproval => 'PendingApproval',
        ComplaintStatus.open => 'Open',
        ComplaintStatus.assigned => 'Assigned',
        ComplaintStatus.inProgress => 'InProgress',
        ComplaintStatus.resolved => 'Resolved',
        ComplaintStatus.closed => 'Closed',
        ComplaintStatus.rejected => 'Rejected',
      };

  String get label => switch (this) {
        ComplaintStatus.pendingApproval => 'Pending Approval',
        ComplaintStatus.open => 'Open',
        ComplaintStatus.assigned => 'Assigned',
        ComplaintStatus.inProgress => 'In Progress',
        ComplaintStatus.resolved => 'Resolved',
        ComplaintStatus.closed => 'Closed',
        ComplaintStatus.rejected => 'Rejected',
      };

  Color get color => switch (this) {
        ComplaintStatus.pendingApproval => AppColors.warn,
        ComplaintStatus.open => AppColors.warn,
        ComplaintStatus.assigned => AppColors.accent,
        ComplaintStatus.inProgress => AppColors.accent,
        ComplaintStatus.resolved => AppColors.ok,
        ComplaintStatus.closed => AppColors.neutral,
        ComplaintStatus.rejected => AppColors.bad,
      };
}

/// Chosen by the complainer at submission time (not auto-computed from
/// category, unlike the real backend's current `TicketPriority`). Order
/// matches how it should read in pickers: most to least severe.
enum ComplaintSeverity {
  critical,
  urgent,
  medium,
  low;

  static ComplaintSeverity fromJson(String value) => switch (value) {
        'Critical' => ComplaintSeverity.critical,
        // The real backend's priority scale tops out at "High" — treated
        // as Urgent here since the app's scale has no High.
        'Urgent' || 'High' => ComplaintSeverity.urgent,
        'Medium' => ComplaintSeverity.medium,
        'Low' => ComplaintSeverity.low,
        _ => throw ArgumentError('Unknown ComplaintSeverity: $value'),
      };

  String toJson() => switch (this) {
        ComplaintSeverity.critical => 'Critical',
        ComplaintSeverity.urgent => 'Urgent',
        ComplaintSeverity.medium => 'Medium',
        ComplaintSeverity.low => 'Low',
      };

  String get label => switch (this) {
        ComplaintSeverity.critical => 'Critical',
        ComplaintSeverity.urgent => 'Urgent',
        ComplaintSeverity.medium => 'Medium',
        ComplaintSeverity.low => 'Low',
      };

  /// First letter of the severity, used as the leading character of the
  /// complaint number (e.g. "U-0007-IT-20260710").
  String get letter => switch (this) {
        ComplaintSeverity.critical => 'C',
        ComplaintSeverity.urgent => 'U',
        ComplaintSeverity.medium => 'M',
        ComplaintSeverity.low => 'L',
      };

  Color get color => switch (this) {
        ComplaintSeverity.critical => AppColors.bad,
        ComplaintSeverity.urgent => AppColors.warn,
        ComplaintSeverity.medium => AppColors.accent,
        ComplaintSeverity.low => AppColors.ok,
      };

  /// Expected time-to-resolution before the complaint is flagged overdue.
  /// Not specified by the backend (no SLA concept there yet) — these are
  /// the mobile app's own defaults, applied client-side against the mock
  /// backend's `assignedAt`/`createdAt`.
  Duration get slaDuration => switch (this) {
        ComplaintSeverity.critical => const Duration(hours: 4),
        ComplaintSeverity.urgent => const Duration(hours: 24),
        ComplaintSeverity.medium => const Duration(hours: 72),
        ComplaintSeverity.low => const Duration(hours: 120),
      };
}

enum NotificationType {
  complaintAssigned,
  complaintStatusChanged,
  complaintClosed,
  complaintOverdue,
  feedbackRequested,
  visitorOtp,
  visitorArrived,
  visitorDeparted,
  // Mobile-only for now, like complaintOverdue: raised by the mock parking
  // reader / RFID scanners. No backend wire string exists yet for either.
  parkingAlert,
  zoneViolation,
  system;

  /// The REST endpoint (`GET /api/notifications`) serializes this as a
  /// string (JsonStringEnumConverter is registered for MVC). The SignalR
  /// hub does NOT share that converter — `AddSignalR()` has no
  /// `.AddJsonProtocol()` override — so a live-pushed notification carries
  /// this field as a raw int matching the C# enum's declaration order.
  /// Both shapes are handled here since either can reach this app. Note
  /// the real backend's enum is named "TicketXxx" — the wire strings below
  /// reflect that; only the Dart member names were renamed for in-app
  /// terminology. `complaintOverdue` is mobile-app-only (SLA alerts have
  /// no backend counterpart yet) and never arrives via fromJson.
  static NotificationType fromJson(dynamic value) {
    if (value is int) {
      // int.clamp() returns num, not int — .toInt() gets a valid list index.
      return NotificationType.values[value.clamp(0, NotificationType.values.length - 1).toInt()];
    }
    return switch (value as String) {
      'TicketAssigned' => NotificationType.complaintAssigned,
      'TicketStatusChanged' => NotificationType.complaintStatusChanged,
      'TicketClosed' => NotificationType.complaintClosed,
      'FeedbackRequested' => NotificationType.feedbackRequested,
      'VisitorOtp' => NotificationType.visitorOtp,
      'VisitorArrived' => NotificationType.visitorArrived,
      'VisitorDeparted' => NotificationType.visitorDeparted,
      _ => NotificationType.system,
    };
  }

  IconData get icon => switch (this) {
        NotificationType.complaintAssigned => Icons.assignment_ind_outlined,
        NotificationType.complaintStatusChanged => Icons.sync_alt,
        NotificationType.complaintClosed => Icons.check_circle_outline,
        NotificationType.complaintOverdue => Icons.warning_amber_outlined,
        NotificationType.feedbackRequested => Icons.star_border,
        NotificationType.visitorOtp ||
        NotificationType.visitorArrived ||
        NotificationType.visitorDeparted =>
          Icons.badge_outlined,
        NotificationType.parkingAlert => Icons.local_parking_outlined,
        NotificationType.zoneViolation => Icons.gpp_maybe_outlined,
        NotificationType.system => Icons.info_outline,
      };
}
