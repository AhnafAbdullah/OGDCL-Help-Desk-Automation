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

enum TicketStatus {
  open,
  assigned,
  inProgress,
  resolved,
  closed;

  static TicketStatus fromJson(String value) => switch (value) {
        'Open' => TicketStatus.open,
        'Assigned' => TicketStatus.assigned,
        'InProgress' => TicketStatus.inProgress,
        'Resolved' => TicketStatus.resolved,
        'Closed' => TicketStatus.closed,
        _ => throw ArgumentError('Unknown TicketStatus: $value'),
      };

  String toJson() => switch (this) {
        TicketStatus.open => 'Open',
        TicketStatus.assigned => 'Assigned',
        TicketStatus.inProgress => 'InProgress',
        TicketStatus.resolved => 'Resolved',
        TicketStatus.closed => 'Closed',
      };

  String get label => switch (this) {
        TicketStatus.open => 'Open',
        TicketStatus.assigned => 'Assigned',
        TicketStatus.inProgress => 'In Progress',
        TicketStatus.resolved => 'Resolved',
        TicketStatus.closed => 'Closed',
      };

  Color get color => switch (this) {
        TicketStatus.open => AppColors.warn,
        TicketStatus.assigned => AppColors.accent,
        TicketStatus.inProgress => AppColors.accent,
        TicketStatus.resolved => AppColors.ok,
        TicketStatus.closed => AppColors.neutral,
      };
}

enum TicketPriority {
  low,
  medium,
  high,
  critical;

  static TicketPriority fromJson(String value) => switch (value) {
        'Low' => TicketPriority.low,
        'Medium' => TicketPriority.medium,
        'High' => TicketPriority.high,
        'Critical' => TicketPriority.critical,
        _ => throw ArgumentError('Unknown TicketPriority: $value'),
      };

  String get label => switch (this) {
        TicketPriority.low => 'Low',
        TicketPriority.medium => 'Medium',
        TicketPriority.high => 'High',
        TicketPriority.critical => 'Critical',
      };

  Color get color => switch (this) {
        TicketPriority.low => AppColors.ok,
        TicketPriority.medium => AppColors.accent,
        TicketPriority.high => AppColors.warn,
        TicketPriority.critical => AppColors.bad,
      };
}

enum NotificationType {
  ticketAssigned,
  ticketStatusChanged,
  ticketClosed,
  feedbackRequested,
  visitorOtp,
  visitorArrived,
  visitorDeparted,
  system;

  /// The REST endpoint (`GET /api/notifications`) serializes this as a
  /// string (JsonStringEnumConverter is registered for MVC). The SignalR
  /// hub does NOT share that converter — `AddSignalR()` has no
  /// `.AddJsonProtocol()` override — so a live-pushed notification carries
  /// this field as a raw int matching the C# enum's declaration order.
  /// Both shapes are handled here since either can reach this app.
  static NotificationType fromJson(dynamic value) {
    if (value is int) {
      // int.clamp() returns num, not int — .toInt() gets a valid list index.
      return NotificationType.values[value.clamp(0, NotificationType.values.length - 1).toInt()];
    }
    return switch (value as String) {
      'TicketAssigned' => NotificationType.ticketAssigned,
      'TicketStatusChanged' => NotificationType.ticketStatusChanged,
      'TicketClosed' => NotificationType.ticketClosed,
      'FeedbackRequested' => NotificationType.feedbackRequested,
      'VisitorOtp' => NotificationType.visitorOtp,
      'VisitorArrived' => NotificationType.visitorArrived,
      'VisitorDeparted' => NotificationType.visitorDeparted,
      _ => NotificationType.system,
    };
  }

  IconData get icon => switch (this) {
        NotificationType.ticketAssigned => Icons.assignment_ind_outlined,
        NotificationType.ticketStatusChanged => Icons.sync_alt,
        NotificationType.ticketClosed => Icons.check_circle_outline,
        NotificationType.feedbackRequested => Icons.star_border,
        NotificationType.visitorOtp ||
        NotificationType.visitorArrived ||
        NotificationType.visitorDeparted =>
          Icons.badge_outlined,
        NotificationType.system => Icons.info_outline,
      };
}
