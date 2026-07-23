import '../domain/category.dart';
import '../domain/complaint.dart';
import '../domain/enums.dart';
import '../domain/app_notification.dart';
import '../domain/user.dart';

/// A seeded demo account — mirrors the backend's dev seeder (same
/// usernames/passwords/roles) so the credentials in the README work
/// identically against the mock backend or the real one. Admin accounts
/// are kept here only so login can correctly *reject* them — Admin is a
/// web-dashboard-only role and never reaches the mobile app.
class MockAccount {
  const MockAccount({
    required this.id,
    required this.username,
    required this.password,
    required this.displayName,
    required this.email,
    required this.role,
    this.department,
    this.designation,
  });

  final int id;
  final String username;
  final String password;
  final String displayName;
  final String email;
  final UserRole role;
  final String? department;
  final String? designation;

  User toUser() => User(
        id: id,
        username: username,
        displayName: displayName,
        email: email,
        role: role,
        department: department,
        designation: designation,
      );
}

class _NotificationRecord {
  _NotificationRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final int id;
  final int userId;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  DateTime? readAt;

  AppNotification toDto() => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        createdAt: createdAt,
        readAt: readAt,
      );
}

/// A single in-memory stand-in for the whole backend, used when
/// [Env.useMockBackend] is true. Mirrors the app's Help Desk workflow
/// (severity-driven approval routing, handler self-assignment, SLA
/// overdue alerts) closely enough to demo the whole thing with no server
/// running. All mock repositories share this one instance.
class MockDatabase {
  MockDatabase._() {
    _seedComplaints();
    _seedNotifications();
  }

  static final MockDatabase instance = MockDatabase._();

  /// Set by MockAuthRepository on login/logout; read by the complaint and
  /// notification repositories to scope "mine"/"assigned"/notification
  /// queries, the same way the real backend derives it from the JWT.
  User? currentUser;

  static const List<MockAccount> accounts = [
    MockAccount(
      id: 1,
      username: 'admin',
      password: 'Admin@123',
      displayName: 'System Admin',
      email: 'admin@ogdcl.com',
      role: UserRole.admin,
      designation: 'System Administrator',
    ),
    MockAccount(
      id: 2,
      username: 'ayan',
      password: 'Employee@123',
      displayName: 'Muhammad Ayan',
      email: 'ayan@ogdcl.com',
      role: UserRole.employee,
      designation: 'Administrative Officer',
    ),
    MockAccount(
      id: 3,
      username: 'umer',
      password: 'Employee@123',
      displayName: 'Muhammad Umer',
      email: 'umer@ogdcl.com',
      role: UserRole.employee,
      designation: 'Finance Analyst',
    ),
    MockAccount(
      id: 4,
      username: 'ibrahim',
      password: 'Employee@123',
      displayName: 'Ibrahim Ahmad',
      email: 'ibrahim@ogdcl.com',
      role: UserRole.employee,
      designation: 'Software Engineer',
    ),
    MockAccount(
      id: 5,
      username: 'it.handler1',
      password: 'Handler@123',
      displayName: 'Bilal Sheikh',
      email: 'it.handler1@ogdcl.com',
      role: UserRole.handler,
      department: 'IT Support',
      designation: 'IT Support Specialist',
    ),
    MockAccount(
      id: 6,
      username: 'it.handler2',
      password: 'Handler@123',
      displayName: 'Sana Tariq',
      email: 'it.handler2@ogdcl.com',
      role: UserRole.handler,
      department: 'IT Support',
      designation: 'IT Support Specialist',
    ),
    MockAccount(
      id: 7,
      username: 'maint.handler1',
      password: 'Handler@123',
      displayName: 'Waqas Iqbal',
      email: 'maint.handler1@ogdcl.com',
      role: UserRole.handler,
      department: 'Maintenance',
      designation: 'Maintenance Supervisor',
    ),
    MockAccount(
      id: 8,
      username: 'hr.handler1',
      password: 'Handler@123',
      displayName: 'Ayesha Noor',
      email: 'hr.handler1@ogdcl.com',
      role: UserRole.handler,
      department: 'HR',
      designation: 'HR Officer',
    ),
    MockAccount(
      id: 9,
      username: 'fac.handler1',
      password: 'Handler@123',
      displayName: 'Kamran Zafar',
      email: 'fac.handler1@ogdcl.com',
      role: UserRole.handler,
      department: 'Facilities',
      designation: 'Facilities Supervisor',
    ),
    MockAccount(
      id: 10,
      username: 'civil.handler1',
      password: 'Handler@123',
      displayName: 'Hassan Raza',
      email: 'civil.handler1@ogdcl.com',
      role: UserRole.handler,
      department: 'Civil Works',
      designation: 'Civil Works Engineer',
    ),
    MockAccount(
      id: 11,
      username: 'guard1',
      password: 'Guard@123',
      displayName: 'Security Guard One',
      email: 'guard1@ogdcl.com',
      role: UserRole.security,
      designation: 'Security Guard',
    ),
    MockAccount(
      id: 12,
      username: 'guard2',
      password: 'Guard@123',
      displayName: 'Security Guard Two',
      email: 'guard2@ogdcl.com',
      role: UserRole.security,
      designation: 'Security Guard',
    ),
  ];

  static const List<Category> categories = [
    Category(id: 1, name: 'IT Support'),
    Category(id: 2, name: 'Maintenance'),
    Category(id: 3, name: 'HR'),
    Category(id: 4, name: 'Facilities'),
    Category(id: 5, name: 'Civil Works'),
  ];

  static const Map<int, String> _departmentByCategoryId = {
    1: 'IT Support',
    2: 'Maintenance',
    3: 'HR',
    4: 'Facilities',
    5: 'Civil Works',
  };

  /// Short code used in the complaint number (e.g. "U-0007-IT-20260710").
  static const Map<int, String> _deptCodeByCategoryId = {
    1: 'IT',
    2: 'MNT',
    3: 'HR',
    4: 'FAC',
    5: 'CIV',
  };

  final List<Complaint> _complaints = [];
  int _nextComplaintId = 100;
  int _complaintSequence = 10;

  final List<_NotificationRecord> _notifications = [];
  int _nextNotificationId = 100;

  /// Complaint ids an overdue alert has already been raised for, so
  /// [checkOverdueAndNotify] doesn't re-notify on every poll.
  final Set<int> _overdueNotified = {};

  MockAccount? accountByCredentials(String username, String password) {
    for (final a in accounts) {
      if (a.username.toLowerCase() == username.trim().toLowerCase() && a.password == password) {
        return a;
      }
    }
    return null;
  }

  MockAccount accountById(int id) => accounts.firstWhere((a) => a.id == id);

  // ------------------------------------------------------------- Complaints

  List<Complaint> get allComplaints => List.unmodifiable(_complaints);

  Complaint byId(int id) => _complaints.firstWhere((c) => c.id == id);

  Complaint createComplaint({
    required int categoryId,
    required String title,
    required String description,
    required ComplaintSeverity severity,
    required User creator,
  }) {
    final category = categories.firstWhere((c) => c.id == categoryId);
    final department = _departmentByCategoryId[categoryId];
    final now = DateTime.now();
    final id = _nextComplaintId++;
    final complaintNumber = _generateComplaintNumber(
      severity: severity,
      categoryId: categoryId,
      date: now,
    );

    // Critical severity is gated behind admin approval (handled on the web
    // dashboard — Admin has no mobile presence); everything else lands in
    // the department's open queue for any handler there to pick up.
    final status =
        severity == ComplaintSeverity.critical ? ComplaintStatus.pendingApproval : ComplaintStatus.open;

    final complaint = Complaint(
      id: id,
      complaintNumber: complaintNumber,
      title: title,
      description: description,
      category: category.name,
      status: status,
      severity: severity,
      createdBy: creator.displayName,
      createdById: creator.id,
      department: department,
      createdAt: now,
      updatedAt: now,
      statusHistory: [
        StatusHistoryEntry(
          toStatus: status,
          note: status == ComplaintStatus.pendingApproval
              ? 'Submitted — Critical severity requires admin approval before routing.'
              : 'Complaint submitted.',
          changedBy: creator.displayName,
          changedAt: now,
        ),
      ],
      attachments: const [],
    );
    _complaints.add(complaint);
    return complaint;
  }

  /// A handler picking an unassigned (Open) complaint in their own
  /// department off the shared queue.
  Complaint selfAssign(int id, {required User handler}) {
    final index = _complaints.indexWhere((c) => c.id == id);
    final complaint = _complaints[index];
    final now = DateTime.now();
    final history = [
      ...complaint.statusHistory,
      StatusHistoryEntry(
        fromStatus: complaint.status,
        toStatus: ComplaintStatus.assigned,
        note: 'Self-assigned by ${handler.displayName}',
        changedBy: handler.displayName,
        changedAt: now,
      ),
    ];

    final updated = Complaint(
      id: complaint.id,
      complaintNumber: complaint.complaintNumber,
      title: complaint.title,
      description: complaint.description,
      category: complaint.category,
      status: ComplaintStatus.assigned,
      severity: complaint.severity,
      createdBy: complaint.createdBy,
      createdById: complaint.createdById,
      assignedTo: handler.displayName,
      assignedToId: handler.id,
      department: complaint.department,
      createdAt: complaint.createdAt,
      updatedAt: now,
      assignedAt: now,
      resolvedAt: complaint.resolvedAt,
      closedAt: complaint.closedAt,
      rejectionReason: complaint.rejectionReason,
      feedback: complaint.feedback,
      statusHistory: history,
      attachments: complaint.attachments,
    );
    _complaints[index] = updated;

    _addNotification(
      userId: complaint.createdById,
      type: NotificationType.complaintAssigned,
      title: 'Complaint ${complaint.complaintNumber} picked up',
      body: '"${complaint.title}" is now being handled by ${handler.displayName}.',
    );
    return updated;
  }

  Complaint updateStatus(
    int id, {
    required ComplaintStatus status,
    String? note,
    required User actor,
  }) {
    final index = _complaints.indexWhere((c) => c.id == id);
    final complaint = _complaints[index];
    final now = DateTime.now();
    final history = [
      ...complaint.statusHistory,
      StatusHistoryEntry(
        fromStatus: complaint.status,
        toStatus: status,
        note: note,
        changedBy: actor.displayName,
        changedAt: now,
      ),
    ];

    final updated = Complaint(
      id: complaint.id,
      complaintNumber: complaint.complaintNumber,
      title: complaint.title,
      description: complaint.description,
      category: complaint.category,
      status: status,
      severity: complaint.severity,
      createdBy: complaint.createdBy,
      createdById: complaint.createdById,
      assignedTo: complaint.assignedTo,
      assignedToId: complaint.assignedToId,
      department: complaint.department,
      createdAt: complaint.createdAt,
      updatedAt: now,
      assignedAt: complaint.assignedAt,
      resolvedAt: status == ComplaintStatus.resolved
          ? now
          : (status == ComplaintStatus.inProgress ? null : complaint.resolvedAt),
      closedAt: status == ComplaintStatus.closed ? now : complaint.closedAt,
      rejectionReason: complaint.rejectionReason,
      feedback: complaint.feedback,
      statusHistory: history,
      attachments: complaint.attachments,
    );
    _complaints[index] = updated;

    if (status == ComplaintStatus.closed) {
      if (complaint.createdById != actor.id) {
        _addNotification(
          userId: complaint.createdById,
          type: NotificationType.complaintClosed,
          title: 'Complaint ${complaint.complaintNumber} closed',
          body: '"${complaint.title}" has been closed.',
        );
      }
    } else {
      final others = <int>{};
      if (complaint.createdById != actor.id) others.add(complaint.createdById);
      if (complaint.assignedToId != null && complaint.assignedToId != actor.id) {
        others.add(complaint.assignedToId!);
      }
      for (final uid in others) {
        _addNotification(
          userId: uid,
          type: NotificationType.complaintStatusChanged,
          title: 'Complaint ${complaint.complaintNumber}: ${complaint.status.label} → ${status.label}',
          body: '"${complaint.title}" was moved to ${status.label} by ${actor.displayName}.',
        );
      }
      if (status == ComplaintStatus.resolved) {
        _addNotification(
          userId: complaint.createdById,
          type: NotificationType.feedbackRequested,
          title: 'How was complaint ${complaint.complaintNumber} handled?',
          body: 'Your complaint has been resolved. Please rate how it was handled.',
        );
      }
    }

    return updated;
  }

  Complaint submitFeedback(int id, {required int rating, String? comment}) {
    final index = _complaints.indexWhere((c) => c.id == id);
    final complaint = _complaints[index];
    final updated = Complaint(
      id: complaint.id,
      complaintNumber: complaint.complaintNumber,
      title: complaint.title,
      description: complaint.description,
      category: complaint.category,
      status: complaint.status,
      severity: complaint.severity,
      createdBy: complaint.createdBy,
      createdById: complaint.createdById,
      assignedTo: complaint.assignedTo,
      assignedToId: complaint.assignedToId,
      department: complaint.department,
      createdAt: complaint.createdAt,
      updatedAt: DateTime.now(),
      assignedAt: complaint.assignedAt,
      resolvedAt: complaint.resolvedAt,
      closedAt: complaint.closedAt,
      rejectionReason: complaint.rejectionReason,
      feedback: ComplaintFeedback(rating: rating, comment: comment, createdAt: DateTime.now()),
      statusHistory: complaint.statusHistory,
      attachments: complaint.attachments,
    );
    _complaints[index] = updated;
    return updated;
  }

  Complaint addAttachment(
    int id, {
    required String fileName,
    required String contentType,
    required int sizeBytes,
  }) {
    final index = _complaints.indexWhere((c) => c.id == id);
    final complaint = _complaints[index];
    final attachment = Attachment(
      id: (index + 1) * 1000 + complaint.attachments.length + 1,
      fileName: fileName,
      contentType: contentType,
      sizeBytes: sizeBytes,
      uploadedAt: DateTime.now(),
    );
    final updated = Complaint(
      id: complaint.id,
      complaintNumber: complaint.complaintNumber,
      title: complaint.title,
      description: complaint.description,
      category: complaint.category,
      status: complaint.status,
      severity: complaint.severity,
      createdBy: complaint.createdBy,
      createdById: complaint.createdById,
      assignedTo: complaint.assignedTo,
      assignedToId: complaint.assignedToId,
      department: complaint.department,
      createdAt: complaint.createdAt,
      updatedAt: DateTime.now(),
      assignedAt: complaint.assignedAt,
      resolvedAt: complaint.resolvedAt,
      closedAt: complaint.closedAt,
      rejectionReason: complaint.rejectionReason,
      feedback: complaint.feedback,
      statusHistory: complaint.statusHistory,
      attachments: [...complaint.attachments, attachment],
    );
    _complaints[index] = updated;
    return updated;
  }

  /// Scans active complaints for SLA breaches and raises a one-time
  /// overdue notification for each newly-breached one. Called lazily from
  /// the repository's read paths — there's no real background scheduler
  /// in a mock/offline app, so "the alert generates" the moment the app
  /// next asks for the affected list.
  void checkOverdueAndNotify() {
    for (final c in _complaints) {
      if (c.isOverdue && !_overdueNotified.contains(c.id) && c.assignedToId != null) {
        _overdueNotified.add(c.id);
        _addNotification(
          userId: c.assignedToId!,
          type: NotificationType.complaintOverdue,
          title: 'Complaint ${c.complaintNumber} is overdue',
          body:
              '"${c.title}" (${c.severity.label}) has exceeded its ${_formatSla(c.severity.slaDuration)} SLA.',
        );
      }
    }
  }

  String _formatSla(Duration d) => d.inHours < 24 ? '${d.inHours}-hour' : '${d.inDays}-day';

  String _generateComplaintNumber({
    required ComplaintSeverity severity,
    required int categoryId,
    required DateTime date,
  }) {
    final seq = (++_complaintSequence).toString().padLeft(4, '0');
    final deptCode = _deptCodeByCategoryId[categoryId] ?? 'GEN';
    final dateStr = '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
    return '${severity.letter}-$seq-$deptCode-$dateStr';
  }

  // ----------------------------------------------------------- Notifications

  void _addNotification({
    required int userId,
    required NotificationType type,
    required String title,
    required String body,
  }) {
    _notifications.add(_NotificationRecord(
      id: _nextNotificationId++,
      userId: userId,
      type: type,
      title: title,
      body: body,
      createdAt: DateTime.now(),
    ));
  }

  List<AppNotification> notificationsFor(int userId) => _notifications
      .where((n) => n.userId == userId)
      .toList()
      .reversed
      .map((n) => n.toDto())
      .toList();

  void markNotificationRead(int userId, int notificationId) {
    for (final n in _notifications) {
      if (n.id == notificationId && n.userId == userId) {
        n.readAt = DateTime.now();
        return;
      }
    }
  }

  // ------------------------------------------------------------- Seed data

  void _seedComplaints() {
    final now = DateTime.now();
    DateTime daysAgo(int d, [int h = 9]) => now.subtract(Duration(days: d, hours: 24 - h));

    void seed({
      required int id,
      required String number,
      required String title,
      required String description,
      required String category,
      required ComplaintStatus status,
      required ComplaintSeverity severity,
      required MockAccount creator,
      MockAccount? handler,
      DateTime? assignedAt,
      ComplaintFeedback? feedback,
      String? rejectionReason,
      required List<StatusHistoryEntry> history,
      required DateTime createdAt,
      required DateTime updatedAt,
    }) {
      _complaints.add(Complaint(
        id: id,
        complaintNumber: number,
        title: title,
        description: description,
        category: category,
        status: status,
        severity: severity,
        createdBy: creator.displayName,
        createdById: creator.id,
        assignedTo: handler?.displayName,
        assignedToId: handler?.id,
        department: handler?.department,
        createdAt: createdAt,
        updatedAt: updatedAt,
        assignedAt: assignedAt,
        resolvedAt: status == ComplaintStatus.resolved || status == ComplaintStatus.closed
            ? updatedAt.subtract(const Duration(hours: 2))
            : null,
        closedAt: status == ComplaintStatus.closed ? updatedAt : null,
        rejectionReason: rejectionReason,
        feedback: feedback,
        statusHistory: history,
        attachments: const [],
      ));
    }

    MockAccount acc(String username) => accounts.firstWhere((a) => a.username == username);
    String dateTag(DateTime d) =>
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

    // 1. Critical — awaiting admin approval on the web dashboard.
    seed(
      id: 1,
      number: 'C-0001-IT-${dateTag(daysAgo(0, 5))}',
      title: 'Server room cooling has completely failed',
      description:
          'The AC unit in the 2nd floor server room stopped working entirely; equipment temperature is climbing fast.',
      category: 'IT Support',
      status: ComplaintStatus.pendingApproval,
      severity: ComplaintSeverity.critical,
      creator: acc('ayan'),
      createdAt: daysAgo(0, 5),
      updatedAt: daysAgo(0, 5),
      history: [
        StatusHistoryEntry(
          toStatus: ComplaintStatus.pendingApproval,
          note: 'Submitted — Critical severity requires admin approval before routing.',
          changedBy: acc('ayan').displayName,
          changedAt: daysAgo(0, 5),
        ),
      ],
    );

    // 2. Open — sitting in the department queue, available for any HR handler to pick up.
    seed(
      id: 2,
      number: 'L-0002-HR-${dateTag(daysAgo(0, 6))}',
      title: 'Question about leave policy',
      description: 'Could someone clarify how unused annual leave carries over into next year?',
      category: 'HR',
      status: ComplaintStatus.open,
      severity: ComplaintSeverity.low,
      creator: acc('umer'),
      createdAt: daysAgo(0, 6),
      updatedAt: daysAgo(0, 6),
      history: [
        StatusHistoryEntry(
          toStatus: ComplaintStatus.open,
          note: 'Complaint submitted.',
          changedBy: acc('umer').displayName,
          changedAt: daysAgo(0, 6),
        ),
      ],
    );

    // 3. Assigned, well within SLA.
    seed(
      id: 3,
      number: 'M-0003-MNT-${dateTag(daysAgo(2))}',
      title: 'AC not cooling in room 204',
      description: 'The air conditioning unit in room 204 has been blowing warm air since Monday.',
      category: 'Maintenance',
      status: ComplaintStatus.assigned,
      severity: ComplaintSeverity.medium,
      creator: acc('ibrahim'),
      handler: acc('maint.handler1'),
      assignedAt: daysAgo(2),
      createdAt: daysAgo(2),
      updatedAt: daysAgo(2),
      history: [
        StatusHistoryEntry(
          toStatus: ComplaintStatus.open,
          note: 'Complaint submitted.',
          changedBy: acc('ibrahim').displayName,
          changedAt: daysAgo(2),
        ),
        StatusHistoryEntry(
          fromStatus: ComplaintStatus.open,
          toStatus: ComplaintStatus.assigned,
          note: 'Self-assigned by ${acc('maint.handler1').displayName}',
          changedBy: acc('maint.handler1').displayName,
          changedAt: daysAgo(2),
        ),
      ],
    );

    // 4. In progress, Urgent (24h SLA) but assigned 3 days ago — deliberately overdue.
    seed(
      id: 4,
      number: 'U-0004-CIV-${dateTag(daysAgo(3))}',
      title: 'Ceiling leak near stairwell',
      description: 'Water is dripping from the ceiling near the east stairwell on the 2nd floor.',
      category: 'Civil Works',
      status: ComplaintStatus.inProgress,
      severity: ComplaintSeverity.urgent,
      creator: acc('umer'),
      handler: acc('civil.handler1'),
      assignedAt: daysAgo(3),
      createdAt: daysAgo(3),
      updatedAt: daysAgo(1),
      history: [
        StatusHistoryEntry(
          toStatus: ComplaintStatus.open,
          note: 'Complaint submitted.',
          changedBy: acc('umer').displayName,
          changedAt: daysAgo(3),
        ),
        StatusHistoryEntry(
          fromStatus: ComplaintStatus.open,
          toStatus: ComplaintStatus.assigned,
          note: 'Self-assigned by ${acc('civil.handler1').displayName}',
          changedBy: acc('civil.handler1').displayName,
          changedAt: daysAgo(3),
        ),
        StatusHistoryEntry(
          fromStatus: ComplaintStatus.assigned,
          toStatus: ComplaintStatus.inProgress,
          changedBy: acc('civil.handler1').displayName,
          changedAt: daysAgo(1),
        ),
      ],
    );

    // 5. In progress, Medium (72h SLA), assigned 4 days ago — also overdue.
    seed(
      id: 5,
      number: 'M-0005-IT-${dateTag(daysAgo(4))}',
      title: 'Printer offline on 3rd floor',
      description: 'The shared HP printer on the 3rd floor shows as offline for everyone.',
      category: 'IT Support',
      status: ComplaintStatus.inProgress,
      severity: ComplaintSeverity.medium,
      creator: acc('ayan'),
      handler: acc('it.handler2'),
      assignedAt: daysAgo(4),
      createdAt: daysAgo(4),
      updatedAt: daysAgo(0, 8),
      history: [
        StatusHistoryEntry(
          toStatus: ComplaintStatus.open,
          note: 'Complaint submitted.',
          changedBy: acc('ayan').displayName,
          changedAt: daysAgo(4),
        ),
        StatusHistoryEntry(
          fromStatus: ComplaintStatus.open,
          toStatus: ComplaintStatus.assigned,
          note: 'Self-assigned by ${acc('it.handler2').displayName}',
          changedBy: acc('it.handler2').displayName,
          changedAt: daysAgo(4),
        ),
        StatusHistoryEntry(
          fromStatus: ComplaintStatus.assigned,
          toStatus: ComplaintStatus.inProgress,
          changedBy: acc('it.handler2').displayName,
          changedAt: daysAgo(0, 8),
        ),
      ],
    );

    // 6. Resolved with feedback already left.
    seed(
      id: 6,
      number: 'M-0006-IT-${dateTag(daysAgo(4))}',
      title: "Laptop won't connect to office WiFi",
      description: 'My laptop keeps disconnecting from the OGDCL-Staff network every few minutes.',
      category: 'IT Support',
      status: ComplaintStatus.resolved,
      severity: ComplaintSeverity.medium,
      creator: acc('ibrahim'),
      handler: acc('it.handler1'),
      assignedAt: daysAgo(4),
      feedback: ComplaintFeedback(rating: 5, comment: 'Fixed quickly, thanks!', createdAt: daysAgo(1)),
      createdAt: daysAgo(4),
      updatedAt: daysAgo(1),
      history: [
        StatusHistoryEntry(
          toStatus: ComplaintStatus.open,
          note: 'Complaint submitted.',
          changedBy: acc('ibrahim').displayName,
          changedAt: daysAgo(4),
        ),
        StatusHistoryEntry(
          fromStatus: ComplaintStatus.open,
          toStatus: ComplaintStatus.assigned,
          note: 'Self-assigned by ${acc('it.handler1').displayName}',
          changedBy: acc('it.handler1').displayName,
          changedAt: daysAgo(4),
        ),
        StatusHistoryEntry(
          fromStatus: ComplaintStatus.assigned,
          toStatus: ComplaintStatus.inProgress,
          changedBy: acc('it.handler1').displayName,
          changedAt: daysAgo(3),
        ),
        StatusHistoryEntry(
          fromStatus: ComplaintStatus.inProgress,
          toStatus: ComplaintStatus.resolved,
          note: 'Reset network adapter driver.',
          changedBy: acc('it.handler1').displayName,
          changedAt: daysAgo(1),
        ),
      ],
    );

    // 7. Resolved, feedback not left yet (so "Leave Feedback" is testable).
    seed(
      id: 7,
      number: 'U-0007-CIV-${dateTag(daysAgo(5))}',
      title: 'Crack in parking area pavement',
      description: 'A large crack has formed in the visitor parking area, near the main gate.',
      category: 'Civil Works',
      status: ComplaintStatus.resolved,
      severity: ComplaintSeverity.urgent,
      creator: acc('ibrahim'),
      handler: acc('civil.handler1'),
      assignedAt: daysAgo(5),
      createdAt: daysAgo(5),
      updatedAt: daysAgo(0, 10),
      history: [
        StatusHistoryEntry(
          toStatus: ComplaintStatus.open,
          note: 'Complaint submitted.',
          changedBy: acc('ibrahim').displayName,
          changedAt: daysAgo(5),
        ),
        StatusHistoryEntry(
          fromStatus: ComplaintStatus.open,
          toStatus: ComplaintStatus.assigned,
          note: 'Self-assigned by ${acc('civil.handler1').displayName}',
          changedBy: acc('civil.handler1').displayName,
          changedAt: daysAgo(5),
        ),
        StatusHistoryEntry(
          fromStatus: ComplaintStatus.assigned,
          toStatus: ComplaintStatus.inProgress,
          changedBy: acc('civil.handler1').displayName,
          changedAt: daysAgo(3),
        ),
        StatusHistoryEntry(
          fromStatus: ComplaintStatus.inProgress,
          toStatus: ComplaintStatus.resolved,
          note: 'Patched and resurfaced.',
          changedBy: acc('civil.handler1').displayName,
          changedAt: daysAgo(0, 10),
        ),
      ],
    );

    // 8. Closed with feedback.
    seed(
      id: 8,
      number: 'M-0008-FAC-${dateTag(daysAgo(6))}',
      title: 'Broken chair in conference room B',
      description: 'One of the chairs in conference room B has a broken wheel and is unsafe to use.',
      category: 'Facilities',
      status: ComplaintStatus.closed,
      severity: ComplaintSeverity.medium,
      creator: acc('ayan'),
      handler: acc('fac.handler1'),
      assignedAt: daysAgo(6),
      feedback: ComplaintFeedback(rating: 4, comment: 'Resolved, thanks.', createdAt: daysAgo(2)),
      createdAt: daysAgo(6),
      updatedAt: daysAgo(2),
      history: [
        StatusHistoryEntry(
          toStatus: ComplaintStatus.open,
          note: 'Complaint submitted.',
          changedBy: acc('ayan').displayName,
          changedAt: daysAgo(6),
        ),
        StatusHistoryEntry(
          fromStatus: ComplaintStatus.open,
          toStatus: ComplaintStatus.assigned,
          note: 'Self-assigned by ${acc('fac.handler1').displayName}',
          changedBy: acc('fac.handler1').displayName,
          changedAt: daysAgo(6),
        ),
        StatusHistoryEntry(
          fromStatus: ComplaintStatus.assigned,
          toStatus: ComplaintStatus.inProgress,
          changedBy: acc('fac.handler1').displayName,
          changedAt: daysAgo(5),
        ),
        StatusHistoryEntry(
          fromStatus: ComplaintStatus.inProgress,
          toStatus: ComplaintStatus.resolved,
          changedBy: acc('fac.handler1').displayName,
          changedAt: daysAgo(3),
        ),
        StatusHistoryEntry(
          fromStatus: ComplaintStatus.resolved,
          toStatus: ComplaintStatus.closed,
          changedBy: acc('ayan').displayName,
          changedAt: daysAgo(2),
        ),
      ],
    );

    // 9. Rejected during admin approval (Critical severity that didn't pan out).
    seed(
      id: 9,
      number: 'C-0009-FAC-${dateTag(daysAgo(3))}',
      title: 'Water leakage flagged as critical in east washroom',
      description: 'Reported as an emergency leak near the east washroom.',
      category: 'Facilities',
      status: ComplaintStatus.rejected,
      severity: ComplaintSeverity.critical,
      creator: acc('umer'),
      rejectionReason:
          'Downgraded — this duplicates an existing Civil Works complaint already in progress.',
      createdAt: daysAgo(3),
      updatedAt: daysAgo(2),
      history: [
        StatusHistoryEntry(
          toStatus: ComplaintStatus.pendingApproval,
          note: 'Submitted — Critical severity requires admin approval before routing.',
          changedBy: acc('umer').displayName,
          changedAt: daysAgo(3),
        ),
        StatusHistoryEntry(
          fromStatus: ComplaintStatus.pendingApproval,
          toStatus: ComplaintStatus.rejected,
          note: 'Downgraded — duplicates an existing Civil Works complaint already in progress.',
          changedBy: 'System Admin',
          changedAt: daysAgo(2),
        ),
      ],
    );

    // 10. Assigned, Low severity, plenty of SLA headroom.
    seed(
      id: 10,
      number: 'L-0010-HR-${dateTag(daysAgo(1))}',
      title: 'Need updated employment letter',
      description: 'I need an updated employment verification letter for a bank loan application.',
      category: 'HR',
      status: ComplaintStatus.assigned,
      severity: ComplaintSeverity.low,
      creator: acc('umer'),
      handler: acc('hr.handler1'),
      assignedAt: daysAgo(1),
      createdAt: daysAgo(1),
      updatedAt: daysAgo(1),
      history: [
        StatusHistoryEntry(
          toStatus: ComplaintStatus.open,
          note: 'Complaint submitted.',
          changedBy: acc('umer').displayName,
          changedAt: daysAgo(1),
        ),
        StatusHistoryEntry(
          fromStatus: ComplaintStatus.open,
          toStatus: ComplaintStatus.assigned,
          note: 'Self-assigned by ${acc('hr.handler1').displayName}',
          changedBy: acc('hr.handler1').displayName,
          changedAt: daysAgo(1),
        ),
      ],
    );
  }

  void _seedNotifications() {
    final now = DateTime.now();

    void seedNotif({
      required String username,
      required NotificationType type,
      required String title,
      required String body,
      required DateTime createdAt,
      bool read = false,
    }) {
      final account = accounts.firstWhere((a) => a.username == username);
      _notifications.add(_NotificationRecord(
        id: _nextNotificationId++,
        userId: account.id,
        type: type,
        title: title,
        body: body,
        createdAt: createdAt,
        readAt: read ? createdAt.add(const Duration(minutes: 5)) : null,
      ));
    }

    seedNotif(
      username: 'it.handler1',
      type: NotificationType.complaintAssigned,
      title: 'Complaint M-0006-IT picked up',
      body: '"Laptop won\'t connect to office WiFi" is now yours to work.',
      createdAt: now.subtract(const Duration(days: 4)),
      read: true,
    );
    seedNotif(
      username: 'ibrahim',
      type: NotificationType.feedbackRequested,
      title: 'How was complaint M-0006-IT handled?',
      body: 'Your complaint has been resolved. Please rate how it was handled.',
      createdAt: now.subtract(const Duration(days: 1)),
      read: true,
    );
    seedNotif(
      username: 'civil.handler1',
      type: NotificationType.complaintOverdue,
      title: 'Complaint U-0004-CIV is overdue',
      body: '"Ceiling leak near stairwell" (Urgent) has exceeded its 24-hour SLA.',
      createdAt: now.subtract(const Duration(hours: 6)),
    );
    seedNotif(
      username: 'it.handler2',
      type: NotificationType.complaintOverdue,
      title: 'Complaint M-0005-IT is overdue',
      body: '"Printer offline on 3rd floor" (Medium) has exceeded its 3-day SLA.',
      createdAt: now.subtract(const Duration(hours: 8)),
    );
    seedNotif(
      username: 'ibrahim',
      type: NotificationType.feedbackRequested,
      title: 'How was complaint U-0007-CIV handled?',
      body: 'Your complaint has been resolved. Please rate how it was handled.',
      createdAt: now.subtract(const Duration(hours: 10)),
    );
    seedNotif(
      username: 'umer',
      type: NotificationType.complaintStatusChanged,
      title: 'Complaint C-0009-FAC rejected',
      body: 'Downgraded — duplicates an existing Civil Works complaint already in progress.',
      createdAt: now.subtract(const Duration(days: 2)),
      read: true,
    );
    seedNotif(
      username: 'ayan',
      type: NotificationType.complaintClosed,
      title: 'Complaint M-0008-FAC closed',
      body: '"Broken chair in conference room B" has been closed.',
      createdAt: now.subtract(const Duration(days: 2)),
    );
  }
}
