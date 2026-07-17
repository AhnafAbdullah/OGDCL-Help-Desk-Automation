import '../core/network/api_exception.dart';
import '../domain/category.dart';
import '../domain/complaint.dart';
import '../domain/enums.dart';
import '../domain/user.dart';
import '../features/complaints/data/complaint_repository.dart';
import 'mock_database.dart';

/// Mirrors the app's severity/approval/self-assignment workflow against
/// the in-memory [MockDatabase] instead of a real server.
class MockComplaintRepository implements ComplaintRepository {
  final _db = MockDatabase.instance;

  static const _allowedTransitions = {
    ComplaintStatus.pendingApproval: <ComplaintStatus>[],
    ComplaintStatus.open: [ComplaintStatus.assigned],
    ComplaintStatus.assigned: [ComplaintStatus.inProgress],
    ComplaintStatus.inProgress: [ComplaintStatus.resolved],
    ComplaintStatus.resolved: [ComplaintStatus.closed, ComplaintStatus.inProgress],
    ComplaintStatus.closed: <ComplaintStatus>[],
    ComplaintStatus.rejected: <ComplaintStatus>[],
  };

  User get _actor {
    final user = _db.currentUser;
    if (user == null) throw ApiException('Not signed in.', statusCode: 401);
    return user;
  }

  @override
  Future<List<Category>> categories() async => MockDatabase.categories;

  @override
  Future<Complaint> create({
    required int categoryId,
    required String title,
    required String description,
    required ComplaintSeverity severity,
  }) async {
    if (title.trim().isEmpty) throw ApiException('Title is required.');
    if (description.trim().isEmpty) throw ApiException('Description is required.');
    return _db.createComplaint(
      categoryId: categoryId,
      title: title.trim(),
      description: description.trim(),
      severity: severity,
      creator: _actor,
    );
  }

  @override
  Future<List<ComplaintSummary>> mine() async {
    _db.checkOverdueAndNotify();
    final userId = _actor.id;
    final items =
        _db.allComplaints.where((c) => c.createdById == userId).map(_toSummary).toList();
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  @override
  Future<List<ComplaintSummary>> assigned() async {
    _db.checkOverdueAndNotify();
    final userId = _actor.id;
    final items = _db.allComplaints
        .where((c) => c.assignedToId == userId && c.status != ComplaintStatus.closed)
        .map(_toSummary)
        .toList();
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  @override
  Future<List<ComplaintSummary>> available() async {
    final actor = _actor;
    if (actor.role != UserRole.handler || actor.department == null) return const [];
    final items = _db.allComplaints
        .where((c) => c.status == ComplaintStatus.open && c.department == actor.department)
        .map(_toSummary)
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Future<Complaint> byId(int id) async {
    try {
      return _db.byId(id);
    } on StateError {
      throw ApiException('Complaint not found.', statusCode: 404);
    }
  }

  @override
  Future<Complaint> updateStatus(int id, {required ComplaintStatus status, String? note}) async {
    final complaint = await byId(id);
    final actor = _actor;
    _assertTransitionAllowed(complaint, status, actor);
    return _db.updateStatus(id, status: status, note: note, actor: actor);
  }

  @override
  Future<Complaint> selfAssign(int id, {required int handlerId}) async {
    final actor = _actor;
    if (actor.role != UserRole.handler) {
      throw ApiException('Only handlers can pick up complaints.', statusCode: 403);
    }
    if (handlerId != actor.id) {
      throw ApiException('You can only assign complaints to yourself.', statusCode: 403);
    }
    final complaint = await byId(id);
    if (complaint.status != ComplaintStatus.open) {
      throw ApiException('This complaint has already been picked up.');
    }
    if (actor.department == null || actor.department != complaint.department) {
      throw ApiException('This complaint belongs to a different department.', statusCode: 403);
    }
    return _db.selfAssign(id, handler: actor);
  }

  @override
  Future<Complaint> submitFeedback(int id, {required int rating, String? comment}) async {
    if (rating < 1 || rating > 5) throw ApiException('Rating must be between 1 and 5.');
    final complaint = await byId(id);
    final actor = _actor;
    if (complaint.createdById != actor.id) {
      throw ApiException('Only the complaint creator can leave feedback.', statusCode: 403);
    }
    if (complaint.status != ComplaintStatus.resolved && complaint.status != ComplaintStatus.closed) {
      throw ApiException('Feedback can only be left after the complaint is resolved.');
    }
    if (complaint.feedback != null) {
      throw ApiException('Feedback has already been submitted for this complaint.');
    }
    return _db.submitFeedback(id, rating: rating, comment: comment);
  }

  @override
  Future<Attachment> uploadAttachment(int id, {required String filePath, required String fileName}) async {
    final complaint = await byId(id);
    final actor = _actor;
    if (complaint.createdById != actor.id) {
      throw ApiException('Only the complaint creator can attach files.', statusCode: 403);
    }
    if (complaint.status == ComplaintStatus.closed || complaint.status == ComplaintStatus.rejected) {
      throw ApiException('Attachments cannot be added to a closed or rejected complaint.');
    }
    final updated = _db.addAttachment(
      id,
      fileName: fileName,
      contentType: _guessContentType(fileName),
      sizeBytes: 0,
    );
    return updated.attachments.last;
  }

  @override
  Future<List<int>> downloadAttachment(int complaintId, int attachmentId) async {
    throw ApiException('Attachments are not stored in demo mode.');
  }

  ComplaintSummary _toSummary(Complaint c) => ComplaintSummary(
        id: c.id,
        complaintNumber: c.complaintNumber,
        title: c.title,
        category: c.category,
        status: c.status,
        severity: c.severity,
        createdBy: c.createdBy,
        assignedTo: c.assignedTo,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
        assignedAt: c.assignedAt,
      );

  String _guessContentType(String fileName) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'pdf' => 'application/pdf',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      _ => 'text/plain',
    };
  }

  void _assertTransitionAllowed(Complaint complaint, ComplaintStatus to, User actor) {
    final from = complaint.status;
    if (!(_allowedTransitions[from]?.contains(to) ?? false)) {
      throw ApiException('A complaint cannot move from ${from.label} to ${to.label}.');
    }

    final isAssignedHandler = complaint.assignedToId == actor.id;
    final isCreator = complaint.createdById == actor.id;

    final permitted = (isAssignedHandler &&
            ((from == ComplaintStatus.assigned && to == ComplaintStatus.inProgress) ||
                (from == ComplaintStatus.inProgress && to == ComplaintStatus.resolved) ||
                (from == ComplaintStatus.resolved && to == ComplaintStatus.closed))) ||
        (isCreator &&
            from == ComplaintStatus.resolved &&
            (to == ComplaintStatus.closed || to == ComplaintStatus.inProgress));

    if (!permitted) {
      throw ApiException('You are not allowed to make this status change.', statusCode: 403);
    }
  }
}
