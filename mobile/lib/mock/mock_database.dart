import '../domain/category.dart';
import '../domain/complaint.dart';
import '../domain/enums.dart';
import '../domain/app_notification.dart';
import '../domain/parking.dart';
import '../domain/user.dart';
import '../domain/visitor.dart';

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

class _SlotRecord {
  _SlotRecord({
    required this.id,
    required this.label,
    required this.zone,
    required this.status,
    this.plate,
  });

  final int id;
  final String label;
  final String zone;
  ParkingSlotStatus status;
  String? plate;

  ParkingSlot toDto() =>
      ParkingSlot(id: id, label: label, zone: zone, status: status, plate: plate);
}

class _VehicleRecord {
  _VehicleRecord({
    required this.id,
    required this.plate,
    required this.model,
    required this.color,
    required this.status,
    required this.ownerId,
  });

  final int id;
  final String plate;
  final String model;
  final String color;
  VehicleStatus status;
  final int ownerId;

  Vehicle toDto() =>
      Vehicle(id: id, plate: plate, model: model, color: color, status: status, ownerId: ownerId);
}

class _ParkingAlertRecord {
  _ParkingAlertRecord({
    required this.id,
    required this.plate,
    required this.gate,
    required this.occurredAt,
    this.resolved = false,
  });

  final int id;
  final String plate;
  final String gate;
  final DateTime occurredAt;
  bool resolved;

  ParkingAlert toDto() =>
      ParkingAlert(id: id, plate: plate, gate: gate, occurredAt: occurredAt, resolved: resolved);
}

class _VisitRecord {
  _VisitRecord({
    required this.id,
    required this.visitorName,
    required this.cnic,
    required this.contact,
    required this.purpose,
    required this.hostId,
    required this.expectedArrival,
    required this.allowedZones,
    required this.otp,
    this.status = VisitStatus.preRegistered,
    this.rfidCard,
    this.checkInAt,
    this.checkOutAt,
    List<ZoneEvent>? zoneEvents,
  }) : zoneEvents = zoneEvents ?? [];

  final int id;
  final String visitorName;
  final String cnic;
  final String contact;
  final String purpose;
  final int hostId;
  final DateTime expectedArrival;
  final List<String> allowedZones;
  final String otp;
  VisitStatus status;
  String? rfidCard;
  DateTime? checkInAt;
  DateTime? checkOutAt;
  final List<ZoneEvent> zoneEvents;

  VisitorVisit toDto(String hostName) => VisitorVisit(
        id: id,
        visitorName: visitorName,
        cnic: cnic,
        contact: contact,
        purpose: purpose,
        hostId: hostId,
        hostName: hostName,
        expectedArrival: expectedArrival,
        allowedZones: List.unmodifiable(allowedZones),
        status: status,
        otp: otp,
        rfidCard: rfidCard,
        checkInAt: checkInAt,
        checkOutAt: checkOutAt,
        zoneEvents: List.unmodifiable(zoneEvents),
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
    _seedParking();
    _seedVisitors();
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

  final List<_SlotRecord> _slots = [];
  final List<_VehicleRecord> _vehicles = [];
  final List<_ParkingAlertRecord> _parkingAlerts = [];
  int _nextVehicleId = 100;
  int _nextParkingAlertId = 100;

  final List<_VisitRecord> _visits = [];
  int _nextVisitId = 100;

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

  // ----------------------------------------------------------- Smart Parking

  List<ParkingSlot> parkingSlots() => _slots.map((s) => s.toDto()).toList();

  ParkingOverview parkingOverview() => ParkingOverview(
        total: _slots.length,
        free: _slots.where((s) => s.status == ParkingSlotStatus.free).length,
        occupied: _slots.where((s) => s.status == ParkingSlotStatus.occupied).length,
        flagged: _slots.where((s) => s.status == ParkingSlotStatus.flagged).length,
      );

  List<Vehicle> vehiclesFor(int userId) =>
      _vehicles.where((v) => v.ownerId == userId).map((v) => v.toDto()).toList();

  Vehicle registerVehicle({
    required String plate,
    required String model,
    required String color,
    required User owner,
  }) {
    final record = _VehicleRecord(
      id: _nextVehicleId++,
      plate: plate,
      model: model,
      color: color,
      status: VehicleStatus.pending, // approved by an admin on the web dashboard
      ownerId: owner.id,
    );
    _vehicles.add(record);
    return record.toDto();
  }

  List<ParkingAlert> parkingAlerts() {
    final items = _parkingAlerts.map((a) => a.toDto()).toList();
    items.sort((a, b) {
      if (a.resolved != b.resolved) return a.resolved ? 1 : -1;
      return b.occurredAt.compareTo(a.occurredAt);
    });
    return items;
  }

  void resolveParkingAlert(int id) {
    for (final a in _parkingAlerts) {
      if (a.id == id) {
        a.resolved = true;
        // Security has dealt with the vehicle — clear the flagged slot too.
        for (final s in _slots) {
          if (s.status == ParkingSlotStatus.flagged && s.plate == a.plate) {
            s.status = ParkingSlotStatus.free;
            s.plate = null;
          }
        }
        return;
      }
    }
  }

  // ---------------------------------------------------------- Visitor Entry

  List<VisitorVisit> visitsHostedBy(int userId) {
    final items = _visits
        .where((v) => v.hostId == userId)
        .map((v) => v.toDto(accountById(v.hostId).displayName))
        .toList();
    items.sort((a, b) => b.expectedArrival.compareTo(a.expectedArrival));
    return items;
  }

  /// Everything the gate desk cares about: pending arrivals, visitors
  /// currently inside, and recent departures — newest first.
  List<VisitorVisit> gateVisits() {
    final items = _visits.map((v) => v.toDto(accountById(v.hostId).displayName)).toList();
    items.sort((a, b) => b.expectedArrival.compareTo(a.expectedArrival));
    return items;
  }

  VisitorVisit registerVisitor({
    required String visitorName,
    required String cnic,
    required String contact,
    required String purpose,
    required DateTime expectedArrival,
    required List<String> allowedZones,
    required User host,
  }) {
    final id = _nextVisitId++;
    // Time-limited numeric gate code (proposal §6.3.2). Derived, not
    // random, so the mock stays deterministic enough to demo.
    final otp =
        ((id * 7919 + DateTime.now().millisecondsSinceEpoch) % 900000 + 100000).toString();
    final record = _VisitRecord(
      id: id,
      visitorName: visitorName,
      cnic: cnic,
      contact: contact,
      purpose: purpose,
      hostId: host.id,
      expectedArrival: expectedArrival,
      allowedZones: List.of(allowedZones),
      otp: otp,
    );
    _visits.add(record);

    // The code goes to the guards on duty, not to the host.
    for (final a in accounts.where((a) => a.role == UserRole.security)) {
      _addNotification(
        userId: a.id,
        type: NotificationType.visitorOtp,
        title: 'Visitor code for ${record.visitorName}: $otp',
        body:
            'Expected around ${_clockLabel(expectedArrival)}, visiting ${host.displayName}. Verify this code at the gate.',
      );
    }
    return record.toDto(host.displayName);
  }

  _VisitRecord? _visitByOtp(String code) {
    for (final v in _visits) {
      if (v.status == VisitStatus.preRegistered && v.otp == code.trim()) return v;
    }
    return null;
  }

  bool hasPendingVisitWithOtp(String code) => _visitByOtp(code) != null;

  VisitorVisit checkInVisitor({required String otp, required String rfidCard}) {
    final record = _visitByOtp(otp);
    if (record == null) {
      throw StateError('No pending visit matches that code.');
    }
    record.status = VisitStatus.checkedIn;
    record.checkInAt = DateTime.now();
    record.rfidCard = rfidCard;
    record.zoneEvents.add(ZoneEvent(zone: 'Reception', occurredAt: DateTime.now(), allowed: true));

    final host = accountById(record.hostId);
    _addNotification(
      userId: host.id,
      type: NotificationType.visitorArrived,
      title: '${record.visitorName} has arrived',
      body: 'Checked in at the gate and issued card $rfidCard.',
    );
    return record.toDto(host.displayName);
  }

  VisitorVisit checkOutVisitor(int visitId) {
    final record = _visits.firstWhere((v) => v.id == visitId);
    final card = record.rfidCard;
    record.status = VisitStatus.checkedOut;
    record.checkOutAt = DateTime.now();
    record.rfidCard = null; // card collected and deactivated for reuse

    final host = accountById(record.hostId);
    _addNotification(
      userId: host.id,
      type: NotificationType.visitorDeparted,
      title: '${record.visitorName} has departed',
      body: card == null ? 'Visit closed.' : 'Card $card collected and deactivated.',
    );
    return record.toDto(host.displayName);
  }

  static String _clockLabel(DateTime t) {
    final local = t.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m ${local.hour < 12 ? 'AM' : 'PM'}';
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

  void _seedParking() {
    final now = DateTime.now();

    // Two zones of 12 slots each. Occupancy is a fixed pattern (not random)
    // so every demo run looks the same. A-07 holds the unregistered vehicle
    // that also drives the seeded security alert below.
    const occupiedByZone = {
      'A': {1, 2, 4, 5, 8, 10, 11},
      'B': {2, 3, 6, 9, 12},
    };
    const platesBySlot = {
      'A-01': 'ICT-8842',
      'A-02': 'LEA-2210',
      'A-04': 'IDM-5137',
      'A-05': 'RIX-903',
      'A-08': 'ICT-4471',
      'A-10': 'LEC-7756',
      'A-11': 'GLI-1289',
      'B-02': 'ICT-2903',
      'B-03': 'AJK-4410',
      'B-06': 'LEB-8931',
      'B-09': 'ICT-1165',
      'B-12': 'RIW-624',
    };

    var slotId = 1;
    for (final zone in ['A', 'B']) {
      for (var i = 1; i <= 12; i++) {
        final label = '$zone-${i.toString().padLeft(2, '0')}';
        final occupied = occupiedByZone[zone]!.contains(i);
        _slots.add(_SlotRecord(
          id: slotId++,
          label: label,
          zone: 'Zone $zone',
          status: occupied ? ParkingSlotStatus.occupied : ParkingSlotStatus.free,
          plate: platesBySlot[label],
        ));
      }
    }

    // The unregistered vehicle the entrance reader flagged this morning.
    final flagged = _slots.firstWhere((s) => s.label == 'A-07');
    flagged.status = ParkingSlotStatus.flagged;
    flagged.plate = 'LEB-4821';
    _parkingAlerts.add(_ParkingAlertRecord(
      id: _nextParkingAlertId++,
      plate: 'LEB-4821',
      gate: 'Gate 1',
      occurredAt: now.subtract(const Duration(minutes: 25)),
    ));
    _parkingAlerts.add(_ParkingAlertRecord(
      id: _nextParkingAlertId++,
      plate: 'XYZ-101',
      gate: 'Gate 2',
      occurredAt: now.subtract(const Duration(days: 1, hours: 3)),
      resolved: true,
    ));
    for (final a in accounts.where((a) => a.role == UserRole.security)) {
      _addNotification(
        userId: a.id,
        type: NotificationType.parkingAlert,
        title: 'Unregistered vehicle LEB-4821 at Gate 1',
        body: 'Not on the approved vehicle list. Currently in slot A-07.',
      );
    }

    _vehicles.addAll([
      _VehicleRecord(
        id: _nextVehicleId++,
        plate: 'ICT-8842',
        model: 'Toyota Corolla',
        color: 'White',
        status: VehicleStatus.approved,
        ownerId: 4, // ibrahim
      ),
      _VehicleRecord(
        id: _nextVehicleId++,
        plate: 'ICT-2903',
        model: 'Honda City',
        color: 'Silver',
        status: VehicleStatus.approved,
        ownerId: 2, // ayan
      ),
      _VehicleRecord(
        id: _nextVehicleId++,
        plate: 'RIW-624',
        model: 'Suzuki Cultus',
        color: 'Grey',
        status: VehicleStatus.pending,
        ownerId: 3, // umer
      ),
    ]);
  }

  void _seedVisitors() {
    final now = DateTime.now();

    // Pending arrival — the OTP below is also seeded into the guards'
    // notifications, mirroring how registration pushes the code to them.
    _visits.add(_VisitRecord(
      id: _nextVisitId++,
      visitorName: 'Dr. Salman Khalid',
      cnic: '61101-2455871-3',
      contact: '0301-2245566',
      purpose: 'Network audit meeting with IT',
      hostId: 4, // ibrahim
      expectedArrival: now.add(const Duration(hours: 2)),
      allowedZones: ['Reception', 'IT Wing'],
      otp: '482913',
    ));
    for (final a in accounts.where((a) => a.role == UserRole.security)) {
      _addNotification(
        userId: a.id,
        type: NotificationType.visitorOtp,
        title: 'Visitor code for Dr. Salman Khalid: 482913',
        body:
            'Expected around ${_clockLabel(now.add(const Duration(hours: 2)))}, visiting Ibrahim Ahmad. Verify this code at the gate.',
      );
    }

    // Currently on site — includes a zone violation for the demo, which is
    // what the RFID scanners raise to security (proposal §6.3.3).
    _visits.add(_VisitRecord(
      id: _nextVisitId++,
      visitorName: 'Fatima Janjua',
      cnic: '37405-8812349-2',
      contact: '0333-9184727',
      purpose: 'Vendor contract discussion',
      hostId: 2, // ayan
      expectedArrival: now.subtract(const Duration(hours: 1, minutes: 20)),
      allowedZones: ['Reception', 'Admin Block', 'Conference Hall'],
      otp: '175306',
      status: VisitStatus.checkedIn,
      rfidCard: 'RFID-1027',
      checkInAt: now.subtract(const Duration(hours: 1, minutes: 5)),
      zoneEvents: [
        ZoneEvent(
          zone: 'Reception',
          occurredAt: now.subtract(const Duration(hours: 1, minutes: 5)),
          allowed: true,
        ),
        ZoneEvent(
          zone: 'Conference Hall',
          occurredAt: now.subtract(const Duration(minutes: 40)),
          allowed: true,
        ),
        ZoneEvent(
          zone: 'Finance Wing',
          occurredAt: now.subtract(const Duration(minutes: 12)),
          allowed: false,
        ),
      ],
    ));
    for (final a in accounts.where((a) => a.role == UserRole.security)) {
      _addNotification(
        userId: a.id,
        type: NotificationType.zoneViolation,
        title: 'Zone violation: Fatima Janjua',
        body: 'Card RFID-1027 attempted to enter Finance Wing (not permitted).',
      );
    }

    // Completed visit — full trail: entry, zones, departure, card returned.
    _visits.add(_VisitRecord(
      id: _nextVisitId++,
      visitorName: 'Tariq Mehmood',
      cnic: '61101-7733420-1',
      contact: '0345-6672219',
      purpose: 'Job interview — Finance',
      hostId: 3, // umer
      expectedArrival: now.subtract(const Duration(days: 1, hours: 4)),
      allowedZones: ['Reception', 'Finance Wing'],
      otp: '904417',
      status: VisitStatus.checkedOut,
      checkInAt: now.subtract(const Duration(days: 1, hours: 4)),
      checkOutAt: now.subtract(const Duration(days: 1, hours: 2, minutes: 30)),
      zoneEvents: [
        ZoneEvent(
          zone: 'Reception',
          occurredAt: now.subtract(const Duration(days: 1, hours: 4)),
          allowed: true,
        ),
        ZoneEvent(
          zone: 'Finance Wing',
          occurredAt: now.subtract(const Duration(days: 1, hours: 3, minutes: 45)),
          allowed: true,
        ),
      ],
    ));
  }
}
