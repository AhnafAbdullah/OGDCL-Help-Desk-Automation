import '../core/network/api_exception.dart';
import '../domain/category.dart';
import '../domain/enums.dart';
import '../domain/paged_result.dart';
import '../domain/ticket.dart';
import '../domain/user.dart';
import '../features/tickets/data/handler_option.dart';
import '../features/tickets/data/ticket_repository.dart';
import 'mock_database.dart';

/// Mirrors `TicketService`'s validation and status-transition rules against
/// the in-memory [MockDatabase] instead of a real server.
class MockTicketRepository implements TicketRepository {
  final _db = MockDatabase.instance;

  static const _allowedTransitions = {
    TicketStatus.open: <TicketStatus>[],
    TicketStatus.assigned: [TicketStatus.inProgress],
    TicketStatus.inProgress: [TicketStatus.resolved],
    TicketStatus.resolved: [TicketStatus.closed, TicketStatus.inProgress],
    TicketStatus.closed: <TicketStatus>[],
  };

  User get _actor {
    final user = _db.currentUser;
    if (user == null) throw ApiException('Not signed in.', statusCode: 401);
    return user;
  }

  @override
  Future<List<Category>> categories() async => MockDatabase.categories;

  @override
  Future<Ticket> create({
    required int categoryId,
    required String title,
    required String description,
  }) async {
    if (title.trim().isEmpty) throw ApiException('Title is required.');
    if (description.trim().isEmpty) throw ApiException('Description is required.');
    return _db.createTicket(
      categoryId: categoryId,
      title: title.trim(),
      description: description.trim(),
      creator: _actor,
    );
  }

  @override
  Future<List<TicketSummary>> mine() async {
    final userId = _actor.id;
    final items = _db.allTickets.where((t) => t.createdById == userId).map(_toSummary).toList();
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  @override
  Future<List<TicketSummary>> assigned() async {
    final userId = _actor.id;
    final items = _db.allTickets
        .where((t) => t.assignedToId == userId && t.status != TicketStatus.closed)
        .map(_toSummary)
        .toList();
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  @override
  Future<Ticket> byId(int id) async {
    try {
      return _db.byId(id);
    } on StateError {
      throw ApiException('Ticket not found.', statusCode: 404);
    }
  }

  @override
  Future<Ticket> updateStatus(int id, {required TicketStatus status, String? note}) async {
    final ticket = await byId(id);
    final actor = _actor;
    _assertTransitionAllowed(ticket, status, actor);
    return _db.updateStatus(id, status: status, note: note, actor: actor);
  }

  @override
  Future<Ticket> assign(int id, {required int handlerId}) async {
    final actor = _actor;
    if (actor.role != UserRole.admin) {
      throw ApiException('Only admins can assign tickets manually.', statusCode: 403);
    }
    final ticket = await byId(id);
    if (ticket.status == TicketStatus.closed) {
      throw ApiException('Closed tickets cannot be reassigned.');
    }
    return _db.assign(id, handlerId: handlerId, actor: actor);
  }

  @override
  Future<Ticket> submitFeedback(int id, {required int rating, String? comment}) async {
    if (rating < 1 || rating > 5) throw ApiException('Rating must be between 1 and 5.');
    final ticket = await byId(id);
    final actor = _actor;
    if (ticket.createdById != actor.id) {
      throw ApiException('Only the ticket creator can leave feedback.', statusCode: 403);
    }
    if (ticket.status != TicketStatus.resolved && ticket.status != TicketStatus.closed) {
      throw ApiException('Feedback can only be left after the ticket is resolved.');
    }
    if (ticket.feedback != null) {
      throw ApiException('Feedback has already been submitted for this ticket.');
    }
    return _db.submitFeedback(id, rating: rating, comment: comment);
  }

  @override
  Future<Attachment> uploadAttachment(int id, {required String filePath, required String fileName}) async {
    final ticket = await byId(id);
    final actor = _actor;
    if (ticket.createdById != actor.id && actor.role != UserRole.admin) {
      throw ApiException('Only the ticket creator can attach files.', statusCode: 403);
    }
    if (ticket.status == TicketStatus.closed) {
      throw ApiException('Attachments cannot be added to a closed ticket.');
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
  Future<List<int>> downloadAttachment(int ticketId, int attachmentId) async {
    throw ApiException('Attachments are not stored in demo mode.');
  }

  @override
  Future<PagedResult<TicketSummary>> adminTickets({
    TicketStatus? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final items = _db.allTickets.where((t) => status == null || t.status == status).toList();
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final total = items.length;
    final start = ((page - 1) * pageSize).clamp(0, total).toInt();
    final end = (start + pageSize).clamp(0, total).toInt();
    final pageItems = items.sublist(start, end).map(_toSummary).toList();
    return PagedResult(items: pageItems, total: total, page: page, pageSize: pageSize);
  }

  @override
  Future<int> adminTicketCount({TicketStatus? status}) async =>
      _db.allTickets.where((t) => status == null || t.status == status).length;

  @override
  Future<List<HandlerOption>> activeHandlers() async => MockDatabase.accounts
      .where((a) => a.role == UserRole.handler)
      .map((a) => HandlerOption(id: a.id, displayName: a.displayName, department: a.department, isActive: true))
      .toList();

  TicketSummary _toSummary(Ticket t) => TicketSummary(
        id: t.id,
        ticketNumber: t.ticketNumber,
        title: t.title,
        category: t.category,
        status: t.status,
        priority: t.priority,
        createdBy: t.createdBy,
        assignedTo: t.assignedTo,
        createdAt: t.createdAt,
        updatedAt: t.updatedAt,
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

  void _assertTransitionAllowed(Ticket ticket, TicketStatus to, User actor) {
    final from = ticket.status;
    if (!(_allowedTransitions[from]?.contains(to) ?? false)) {
      throw ApiException('A ticket cannot move from ${from.label} to ${to.label}.');
    }

    final isAdmin = actor.role == UserRole.admin;
    final isAssignedHandler = ticket.assignedToId == actor.id;
    final isCreator = ticket.createdById == actor.id;

    final permitted = isAdmin ||
        (isAssignedHandler &&
            ((from == TicketStatus.assigned && to == TicketStatus.inProgress) ||
                (from == TicketStatus.inProgress && to == TicketStatus.resolved) ||
                (from == TicketStatus.resolved && to == TicketStatus.closed))) ||
        (isCreator &&
            from == TicketStatus.resolved &&
            (to == TicketStatus.closed || to == TicketStatus.inProgress));

    if (!permitted) {
      throw ApiException('You are not allowed to make this status change.', statusCode: 403);
    }
  }
}
