import '../domain/category.dart';
import '../domain/enums.dart';
import '../domain/app_notification.dart';
import '../domain/ticket.dart';
import '../domain/user.dart';

/// A seeded demo account — mirrors the backend's dev seeder (same
/// usernames/passwords/roles) so the credentials in the README work
/// identically against the mock backend or the real one.
class MockAccount {
  const MockAccount({
    required this.id,
    required this.username,
    required this.password,
    required this.displayName,
    required this.email,
    required this.role,
    this.department,
  });

  final int id;
  final String username;
  final String password;
  final String displayName;
  final String email;
  final UserRole role;
  final String? department;

  User toUser() => User(
        id: id,
        username: username,
        displayName: displayName,
        email: email,
        role: role,
        department: department,
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
/// [Env.useMockBackend] is true. Mirrors the real API's behavior (auto
/// routing on create, status-transition history, per-role notifications)
/// closely enough to demo the full Help Desk workflow with no server
/// running. All mock repositories share this one instance.
class MockDatabase {
  MockDatabase._() {
    _seedTickets();
    _seedNotifications();
  }

  static final MockDatabase instance = MockDatabase._();

  /// Set by MockAuthRepository on login/logout; read by the ticket and
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
    ),
    MockAccount(
      id: 2,
      username: 'ayan',
      password: 'Employee@123',
      displayName: 'Muhammad Ayan',
      email: 'ayan@ogdcl.com',
      role: UserRole.employee,
    ),
    MockAccount(
      id: 3,
      username: 'umer',
      password: 'Employee@123',
      displayName: 'Muhammad Umer',
      email: 'umer@ogdcl.com',
      role: UserRole.employee,
    ),
    MockAccount(
      id: 4,
      username: 'ibrahim',
      password: 'Employee@123',
      displayName: 'Ibrahim Ahmad',
      email: 'ibrahim@ogdcl.com',
      role: UserRole.employee,
    ),
    MockAccount(
      id: 5,
      username: 'it.handler1',
      password: 'Handler@123',
      displayName: 'Bilal Sheikh',
      email: 'it.handler1@ogdcl.com',
      role: UserRole.handler,
      department: 'IT Support',
    ),
    MockAccount(
      id: 6,
      username: 'it.handler2',
      password: 'Handler@123',
      displayName: 'Sana Tariq',
      email: 'it.handler2@ogdcl.com',
      role: UserRole.handler,
      department: 'IT Support',
    ),
    MockAccount(
      id: 7,
      username: 'maint.handler1',
      password: 'Handler@123',
      displayName: 'Waqas Iqbal',
      email: 'maint.handler1@ogdcl.com',
      role: UserRole.handler,
      department: 'Maintenance',
    ),
    MockAccount(
      id: 8,
      username: 'hr.handler1',
      password: 'Handler@123',
      displayName: 'Ayesha Noor',
      email: 'hr.handler1@ogdcl.com',
      role: UserRole.handler,
      department: 'HR',
    ),
    MockAccount(
      id: 9,
      username: 'fac.handler1',
      password: 'Handler@123',
      displayName: 'Kamran Zafar',
      email: 'fac.handler1@ogdcl.com',
      role: UserRole.handler,
      department: 'Facilities',
    ),
    MockAccount(
      id: 10,
      username: 'civil.handler1',
      password: 'Handler@123',
      displayName: 'Hassan Raza',
      email: 'civil.handler1@ogdcl.com',
      role: UserRole.handler,
      department: 'Civil Works',
    ),
    MockAccount(
      id: 11,
      username: 'guard1',
      password: 'Guard@123',
      displayName: 'Security Guard One',
      email: 'guard1@ogdcl.com',
      role: UserRole.security,
    ),
    MockAccount(
      id: 12,
      username: 'guard2',
      password: 'Guard@123',
      displayName: 'Security Guard Two',
      email: 'guard2@ogdcl.com',
      role: UserRole.security,
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

  static const Map<int, TicketPriority> _defaultPriorityByCategoryId = {
    1: TicketPriority.medium,
    2: TicketPriority.medium,
    3: TicketPriority.low,
    4: TicketPriority.medium,
    5: TicketPriority.high,
  };

  final List<Ticket> _tickets = [];
  int _nextTicketId = 100;
  int _ticketNumberCounter = 8;

  final List<_NotificationRecord> _notifications = [];
  int _nextNotificationId = 100;

  MockAccount? accountByCredentials(String username, String password) {
    for (final a in accounts) {
      if (a.username.toLowerCase() == username.trim().toLowerCase() && a.password == password) {
        return a;
      }
    }
    return null;
  }

  MockAccount accountById(int id) => accounts.firstWhere((a) => a.id == id);

  List<MockAccount> handlersFor(String department) => accounts
      .where((a) => a.role == UserRole.handler && a.department == department)
      .toList();

  // ---------------------------------------------------------------- Tickets

  List<Ticket> get allTickets => List.unmodifiable(_tickets);

  Ticket byId(int id) => _tickets.firstWhere((t) => t.id == id);

  Ticket createTicket({
    required int categoryId,
    required String title,
    required String description,
    required User creator,
  }) {
    final category = categories.firstWhere((c) => c.id == categoryId);
    final department = _departmentByCategoryId[categoryId];
    final priority = _defaultPriorityByCategoryId[categoryId] ?? TicketPriority.medium;
    final handlers = department == null ? const <MockAccount>[] : handlersFor(department);
    final handler = handlers.isEmpty ? null : handlers.first;

    final now = DateTime.now();
    final id = _nextTicketId++;
    _ticketNumberCounter++;
    final ticketNumber = 'T-${now.year}-${_ticketNumberCounter.toString().padLeft(4, '0')}';
    final status = handler == null ? TicketStatus.open : TicketStatus.assigned;

    final ticket = Ticket(
      id: id,
      ticketNumber: ticketNumber,
      title: title,
      description: description,
      category: category.name,
      status: status,
      priority: priority,
      createdBy: creator.displayName,
      createdById: creator.id,
      assignedTo: handler?.displayName,
      assignedToId: handler?.id,
      department: department,
      createdAt: now,
      updatedAt: now,
      statusHistory: [
        StatusHistoryEntry(
          toStatus: status,
          note: 'Ticket created',
          changedBy: creator.displayName,
          changedAt: now,
        ),
      ],
      attachments: const [],
    );
    _tickets.add(ticket);

    if (handler != null) {
      _addNotification(
        userId: handler.id,
        type: NotificationType.ticketAssigned,
        title: 'New ticket $ticketNumber',
        body: '"$title" (${category.name}) has been assigned to you.',
      );
    }
    return ticket;
  }

  Ticket updateStatus(int id, {required TicketStatus status, String? note, required User actor}) {
    final index = _tickets.indexWhere((t) => t.id == id);
    final ticket = _tickets[index];
    final now = DateTime.now();
    final history = [
      ...ticket.statusHistory,
      StatusHistoryEntry(
        fromStatus: ticket.status,
        toStatus: status,
        note: note,
        changedBy: actor.displayName,
        changedAt: now,
      ),
    ];

    final updated = Ticket(
      id: ticket.id,
      ticketNumber: ticket.ticketNumber,
      title: ticket.title,
      description: ticket.description,
      category: ticket.category,
      status: status,
      priority: ticket.priority,
      createdBy: ticket.createdBy,
      createdById: ticket.createdById,
      assignedTo: ticket.assignedTo,
      assignedToId: ticket.assignedToId,
      department: ticket.department,
      createdAt: ticket.createdAt,
      updatedAt: now,
      resolvedAt: status == TicketStatus.resolved
          ? now
          : (status == TicketStatus.inProgress ? null : ticket.resolvedAt),
      closedAt: status == TicketStatus.closed ? now : ticket.closedAt,
      feedback: ticket.feedback,
      statusHistory: history,
      attachments: ticket.attachments,
    );
    _tickets[index] = updated;

    if (status == TicketStatus.closed) {
      if (ticket.createdById != actor.id) {
        _addNotification(
          userId: ticket.createdById,
          type: NotificationType.ticketClosed,
          title: 'Ticket ${ticket.ticketNumber} closed',
          body: '"${ticket.title}" has been closed.',
        );
      }
    } else {
      final others = <int>{};
      if (ticket.createdById != actor.id) others.add(ticket.createdById);
      if (ticket.assignedToId != null && ticket.assignedToId != actor.id) {
        others.add(ticket.assignedToId!);
      }
      for (final uid in others) {
        _addNotification(
          userId: uid,
          type: NotificationType.ticketStatusChanged,
          title: 'Ticket ${ticket.ticketNumber}: ${ticket.status.label} → ${status.label}',
          body: '"${ticket.title}" was moved to ${status.label} by ${actor.displayName}.',
        );
      }
      if (status == TicketStatus.resolved) {
        _addNotification(
          userId: ticket.createdById,
          type: NotificationType.feedbackRequested,
          title: 'How was ticket ${ticket.ticketNumber} handled?',
          body: 'Your complaint has been resolved. Please rate how it was handled.',
        );
      }
    }

    return updated;
  }

  Ticket assign(int id, {required int handlerId, required User actor}) {
    final index = _tickets.indexWhere((t) => t.id == id);
    final ticket = _tickets[index];
    final handler = accountById(handlerId);
    final now = DateTime.now();
    final newStatus = ticket.status == TicketStatus.open ? TicketStatus.assigned : ticket.status;
    final history = [
      ...ticket.statusHistory,
      StatusHistoryEntry(
        fromStatus: ticket.status,
        toStatus: newStatus,
        note: 'Manually assigned to ${handler.displayName}',
        changedBy: actor.displayName,
        changedAt: now,
      ),
    ];

    final updated = Ticket(
      id: ticket.id,
      ticketNumber: ticket.ticketNumber,
      title: ticket.title,
      description: ticket.description,
      category: ticket.category,
      status: newStatus,
      priority: ticket.priority,
      createdBy: ticket.createdBy,
      createdById: ticket.createdById,
      assignedTo: handler.displayName,
      assignedToId: handler.id,
      department: handler.department ?? ticket.department,
      createdAt: ticket.createdAt,
      updatedAt: now,
      resolvedAt: ticket.resolvedAt,
      closedAt: ticket.closedAt,
      feedback: ticket.feedback,
      statusHistory: history,
      attachments: ticket.attachments,
    );
    _tickets[index] = updated;

    _addNotification(
      userId: handler.id,
      type: NotificationType.ticketAssigned,
      title: 'Ticket ${ticket.ticketNumber} assigned to you',
      body: '"${ticket.title}" has been assigned to you by ${actor.displayName}.',
    );
    return updated;
  }

  Ticket submitFeedback(int id, {required int rating, String? comment}) {
    final index = _tickets.indexWhere((t) => t.id == id);
    final ticket = _tickets[index];
    final updated = Ticket(
      id: ticket.id,
      ticketNumber: ticket.ticketNumber,
      title: ticket.title,
      description: ticket.description,
      category: ticket.category,
      status: ticket.status,
      priority: ticket.priority,
      createdBy: ticket.createdBy,
      createdById: ticket.createdById,
      assignedTo: ticket.assignedTo,
      assignedToId: ticket.assignedToId,
      department: ticket.department,
      createdAt: ticket.createdAt,
      updatedAt: DateTime.now(),
      resolvedAt: ticket.resolvedAt,
      closedAt: ticket.closedAt,
      feedback: TicketFeedback(rating: rating, comment: comment, createdAt: DateTime.now()),
      statusHistory: ticket.statusHistory,
      attachments: ticket.attachments,
    );
    _tickets[index] = updated;
    return updated;
  }

  Ticket addAttachment(int id, {required String fileName, required String contentType, required int sizeBytes}) {
    final index = _tickets.indexWhere((t) => t.id == id);
    final ticket = _tickets[index];
    final attachment = Attachment(
      id: (index + 1) * 1000 + ticket.attachments.length + 1,
      fileName: fileName,
      contentType: contentType,
      sizeBytes: sizeBytes,
      uploadedAt: DateTime.now(),
    );
    final updated = Ticket(
      id: ticket.id,
      ticketNumber: ticket.ticketNumber,
      title: ticket.title,
      description: ticket.description,
      category: ticket.category,
      status: ticket.status,
      priority: ticket.priority,
      createdBy: ticket.createdBy,
      createdById: ticket.createdById,
      assignedTo: ticket.assignedTo,
      assignedToId: ticket.assignedToId,
      department: ticket.department,
      createdAt: ticket.createdAt,
      updatedAt: DateTime.now(),
      resolvedAt: ticket.resolvedAt,
      closedAt: ticket.closedAt,
      feedback: ticket.feedback,
      statusHistory: ticket.statusHistory,
      attachments: [...ticket.attachments, attachment],
    );
    _tickets[index] = updated;
    return updated;
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

  void _seedTickets() {
    final now = DateTime.now();
    DateTime daysAgo(int d, [int h = 9]) => now.subtract(Duration(days: d, hours: 24 - h));

    void seed({
      required int id,
      required String number,
      required String title,
      required String description,
      required String category,
      required TicketStatus status,
      required TicketPriority priority,
      required MockAccount creator,
      MockAccount? handler,
      TicketFeedback? feedback,
      required List<StatusHistoryEntry> history,
      required DateTime createdAt,
      required DateTime updatedAt,
    }) {
      _tickets.add(Ticket(
        id: id,
        ticketNumber: number,
        title: title,
        description: description,
        category: category,
        status: status,
        priority: priority,
        createdBy: creator.displayName,
        createdById: creator.id,
        assignedTo: handler?.displayName,
        assignedToId: handler?.id,
        department: handler?.department,
        createdAt: createdAt,
        updatedAt: updatedAt,
        resolvedAt: status == TicketStatus.resolved || status == TicketStatus.closed
            ? updatedAt.subtract(const Duration(hours: 2))
            : null,
        closedAt: status == TicketStatus.closed ? updatedAt : null,
        feedback: feedback,
        statusHistory: history,
        attachments: const [],
      ));
    }

    MockAccount acc(String username) => accounts.firstWhere((a) => a.username == username);

    seed(
      id: 1,
      number: 'T-${now.year}-0001',
      title: "Laptop won't connect to office WiFi",
      description: 'My laptop keeps disconnecting from the OGDCL-Staff network every few minutes.',
      category: 'IT Support',
      status: TicketStatus.resolved,
      priority: TicketPriority.medium,
      creator: acc('ibrahim'),
      handler: acc('it.handler1'),
      feedback: TicketFeedback(rating: 5, comment: 'Fixed quickly, thanks!', createdAt: daysAgo(1)),
      createdAt: daysAgo(4),
      updatedAt: daysAgo(1),
      history: [
        StatusHistoryEntry(toStatus: TicketStatus.assigned, note: 'Ticket created', changedBy: acc('ibrahim').displayName, changedAt: daysAgo(4)),
        StatusHistoryEntry(fromStatus: TicketStatus.assigned, toStatus: TicketStatus.inProgress, changedBy: acc('it.handler1').displayName, changedAt: daysAgo(3)),
        StatusHistoryEntry(fromStatus: TicketStatus.inProgress, toStatus: TicketStatus.resolved, note: 'Reset network adapter driver.', changedBy: acc('it.handler1').displayName, changedAt: daysAgo(1)),
      ],
    );

    seed(
      id: 2,
      number: 'T-${now.year}-0002',
      title: 'AC not cooling in room 204',
      description: 'The air conditioning unit in room 204 has been blowing warm air since Monday.',
      category: 'Maintenance',
      status: TicketStatus.inProgress,
      priority: TicketPriority.medium,
      creator: acc('ibrahim'),
      handler: acc('maint.handler1'),
      createdAt: daysAgo(2),
      updatedAt: daysAgo(1),
      history: [
        StatusHistoryEntry(toStatus: TicketStatus.assigned, note: 'Ticket created', changedBy: acc('ibrahim').displayName, changedAt: daysAgo(2)),
        StatusHistoryEntry(fromStatus: TicketStatus.assigned, toStatus: TicketStatus.inProgress, changedBy: acc('maint.handler1').displayName, changedAt: daysAgo(1)),
      ],
    );

    seed(
      id: 3,
      number: 'T-${now.year}-0003',
      title: 'Need updated employment letter',
      description: 'I need an updated employment verification letter for a bank loan application.',
      category: 'HR',
      status: TicketStatus.assigned,
      priority: TicketPriority.low,
      creator: acc('umer'),
      handler: acc('hr.handler1'),
      createdAt: daysAgo(1),
      updatedAt: daysAgo(1),
      history: [
        StatusHistoryEntry(toStatus: TicketStatus.assigned, note: 'Ticket created', changedBy: acc('umer').displayName, changedAt: daysAgo(1)),
      ],
    );

    seed(
      id: 4,
      number: 'T-${now.year}-0004',
      title: 'Broken chair in conference room B',
      description: 'One of the chairs in conference room B has a broken wheel and is unsafe to use.',
      category: 'Facilities',
      status: TicketStatus.closed,
      priority: TicketPriority.medium,
      creator: acc('ayan'),
      handler: acc('fac.handler1'),
      feedback: TicketFeedback(rating: 4, comment: 'Resolved, thanks.', createdAt: daysAgo(2)),
      createdAt: daysAgo(6),
      updatedAt: daysAgo(2),
      history: [
        StatusHistoryEntry(toStatus: TicketStatus.assigned, note: 'Ticket created', changedBy: acc('ayan').displayName, changedAt: daysAgo(6)),
        StatusHistoryEntry(fromStatus: TicketStatus.assigned, toStatus: TicketStatus.inProgress, changedBy: acc('fac.handler1').displayName, changedAt: daysAgo(5)),
        StatusHistoryEntry(fromStatus: TicketStatus.inProgress, toStatus: TicketStatus.resolved, changedBy: acc('fac.handler1').displayName, changedAt: daysAgo(3)),
        StatusHistoryEntry(fromStatus: TicketStatus.resolved, toStatus: TicketStatus.closed, changedBy: acc('ayan').displayName, changedAt: daysAgo(2)),
      ],
    );

    seed(
      id: 5,
      number: 'T-${now.year}-0005',
      title: 'Ceiling leak near stairwell',
      description: 'Water is dripping from the ceiling near the east stairwell on the 2nd floor.',
      category: 'Civil Works',
      status: TicketStatus.assigned,
      priority: TicketPriority.high,
      creator: acc('umer'),
      handler: acc('civil.handler1'),
      createdAt: daysAgo(0, 7),
      updatedAt: daysAgo(0, 7),
      history: [
        StatusHistoryEntry(toStatus: TicketStatus.assigned, note: 'Ticket created', changedBy: acc('umer').displayName, changedAt: daysAgo(0, 7)),
      ],
    );

    seed(
      id: 6,
      number: 'T-${now.year}-0006',
      title: 'Printer offline on 3rd floor',
      description: 'The shared HP printer on the 3rd floor shows as offline for everyone.',
      category: 'IT Support',
      status: TicketStatus.inProgress,
      priority: TicketPriority.medium,
      creator: acc('ayan'),
      handler: acc('it.handler2'),
      createdAt: daysAgo(1),
      updatedAt: daysAgo(0, 8),
      history: [
        StatusHistoryEntry(toStatus: TicketStatus.assigned, note: 'Ticket created', changedBy: acc('ayan').displayName, changedAt: daysAgo(1)),
        StatusHistoryEntry(fromStatus: TicketStatus.assigned, toStatus: TicketStatus.inProgress, changedBy: acc('it.handler2').displayName, changedAt: daysAgo(0, 8)),
      ],
    );

    seed(
      id: 7,
      number: 'T-${now.year}-0007',
      title: 'Crack in parking area pavement',
      description: 'A large crack has formed in the visitor parking area, near the main gate.',
      category: 'Civil Works',
      status: TicketStatus.resolved,
      priority: TicketPriority.high,
      creator: acc('ibrahim'),
      handler: acc('civil.handler1'),
      createdAt: daysAgo(5),
      updatedAt: daysAgo(0, 10),
      history: [
        StatusHistoryEntry(toStatus: TicketStatus.assigned, note: 'Ticket created', changedBy: acc('ibrahim').displayName, changedAt: daysAgo(5)),
        StatusHistoryEntry(fromStatus: TicketStatus.assigned, toStatus: TicketStatus.inProgress, changedBy: acc('civil.handler1').displayName, changedAt: daysAgo(3)),
        StatusHistoryEntry(fromStatus: TicketStatus.inProgress, toStatus: TicketStatus.resolved, note: 'Patched and resurfaced.', changedBy: acc('civil.handler1').displayName, changedAt: daysAgo(0, 10)),
      ],
    );

    seed(
      id: 8,
      number: 'T-${now.year}-0008',
      title: 'Question about leave policy',
      description: 'Could someone clarify how unused annual leave carries over into next year?',
      category: 'HR',
      status: TicketStatus.open,
      priority: TicketPriority.low,
      creator: acc('umer'),
      createdAt: daysAgo(0, 6),
      updatedAt: daysAgo(0, 6),
      history: [
        StatusHistoryEntry(toStatus: TicketStatus.open, note: 'Ticket created', changedBy: acc('umer').displayName, changedAt: daysAgo(0, 6)),
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
      type: NotificationType.ticketAssigned,
      title: 'New ticket T-${now.year}-0001',
      body: '"Laptop won\'t connect to office WiFi" (IT Support) has been assigned to you.',
      createdAt: now.subtract(const Duration(days: 4)),
      read: true,
    );
    seedNotif(
      username: 'ibrahim',
      type: NotificationType.feedbackRequested,
      title: 'How was ticket T-${now.year}-0001 handled?',
      body: 'Your complaint has been resolved. Please rate how it was handled.',
      createdAt: now.subtract(const Duration(days: 1)),
      read: true,
    );
    seedNotif(
      username: 'maint.handler1',
      type: NotificationType.ticketAssigned,
      title: 'New ticket T-${now.year}-0002',
      body: '"AC not cooling in room 204" (Maintenance) has been assigned to you.',
      createdAt: now.subtract(const Duration(days: 2)),
    );
    seedNotif(
      username: 'civil.handler1',
      type: NotificationType.ticketAssigned,
      title: 'New ticket T-${now.year}-0005',
      body: '"Ceiling leak near stairwell" (Civil Works) has been assigned to you.',
      createdAt: now.subtract(const Duration(hours: 7)),
    );
    seedNotif(
      username: 'ibrahim',
      type: NotificationType.feedbackRequested,
      title: 'How was ticket T-${now.year}-0007 handled?',
      body: 'Your complaint has been resolved. Please rate how it was handled.',
      createdAt: now.subtract(const Duration(hours: 10)),
    );
    seedNotif(
      username: 'umer',
      type: NotificationType.ticketAssigned,
      title: 'Ticket T-${now.year}-0003 assigned',
      body: '"Need updated employment letter" is now with HR.',
      createdAt: now.subtract(const Duration(days: 1)),
      read: true,
    );
    seedNotif(
      username: 'ayan',
      type: NotificationType.ticketClosed,
      title: 'Ticket T-${now.year}-0004 closed',
      body: '"Broken chair in conference room B" has been closed.',
      createdAt: now.subtract(const Duration(days: 2)),
    );
  }
}
