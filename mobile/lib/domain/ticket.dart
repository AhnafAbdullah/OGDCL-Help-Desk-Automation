import 'enums.dart';

class Attachment {
  const Attachment({
    required this.id,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.uploadedAt,
  });

  final int id;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final DateTime uploadedAt;

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        id: json['id'] as int,
        fileName: json['fileName'] as String,
        contentType: json['contentType'] as String,
        sizeBytes: json['sizeBytes'] as int,
        uploadedAt: DateTime.parse(json['uploadedAt'] as String),
      );
}

class StatusHistoryEntry {
  const StatusHistoryEntry({
    this.fromStatus,
    required this.toStatus,
    this.note,
    required this.changedBy,
    required this.changedAt,
  });

  final TicketStatus? fromStatus;
  final TicketStatus toStatus;
  final String? note;
  final String changedBy;
  final DateTime changedAt;

  factory StatusHistoryEntry.fromJson(Map<String, dynamic> json) => StatusHistoryEntry(
        fromStatus:
            json['fromStatus'] == null ? null : TicketStatus.fromJson(json['fromStatus'] as String),
        toStatus: TicketStatus.fromJson(json['toStatus'] as String),
        note: json['note'] as String?,
        changedBy: json['changedBy'] as String,
        changedAt: DateTime.parse(json['changedAt'] as String),
      );
}

/// Named `TicketFeedback` (not `Feedback`) to avoid colliding with Flutter's
/// own `Feedback` class (haptic/acoustic feedback helper in material.dart).
class TicketFeedback {
  const TicketFeedback({required this.rating, this.comment, required this.createdAt});

  final int rating;
  final String? comment;
  final DateTime createdAt;

  factory TicketFeedback.fromJson(Map<String, dynamic> json) => TicketFeedback(
        rating: json['rating'] as int,
        comment: json['comment'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class TicketSummary {
  const TicketSummary({
    required this.id,
    required this.ticketNumber,
    required this.title,
    required this.category,
    required this.status,
    required this.priority,
    required this.createdBy,
    this.assignedTo,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String ticketNumber;
  final String title;
  final String category;
  final TicketStatus status;
  final TicketPriority priority;
  final String createdBy;
  final String? assignedTo;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TicketSummary.fromJson(Map<String, dynamic> json) => TicketSummary(
        id: json['id'] as int,
        ticketNumber: json['ticketNumber'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        status: TicketStatus.fromJson(json['status'] as String),
        priority: TicketPriority.fromJson(json['priority'] as String),
        createdBy: json['createdBy'] as String,
        assignedTo: json['assignedTo'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

class Ticket {
  const Ticket({
    required this.id,
    required this.ticketNumber,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.priority,
    required this.createdBy,
    required this.createdById,
    this.assignedTo,
    this.assignedToId,
    this.department,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.closedAt,
    this.feedback,
    required this.statusHistory,
    required this.attachments,
  });

  final int id;
  final String ticketNumber;
  final String title;
  final String description;
  final String category;
  final TicketStatus status;
  final TicketPriority priority;
  final String createdBy;
  final int createdById;
  final String? assignedTo;
  final int? assignedToId;
  final String? department;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final TicketFeedback? feedback;
  final List<StatusHistoryEntry> statusHistory;
  final List<Attachment> attachments;

  factory Ticket.fromJson(Map<String, dynamic> json) => Ticket(
        id: json['id'] as int,
        ticketNumber: json['ticketNumber'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        category: json['category'] as String,
        status: TicketStatus.fromJson(json['status'] as String),
        priority: TicketPriority.fromJson(json['priority'] as String),
        createdBy: json['createdBy'] as String,
        createdById: json['createdById'] as int,
        assignedTo: json['assignedTo'] as String?,
        assignedToId: json['assignedToId'] as int?,
        department: json['department'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        resolvedAt: json['resolvedAt'] == null ? null : DateTime.parse(json['resolvedAt'] as String),
        closedAt: json['closedAt'] == null ? null : DateTime.parse(json['closedAt'] as String),
        feedback: json['feedback'] == null
            ? null
            : TicketFeedback.fromJson(json['feedback'] as Map<String, dynamic>),
        statusHistory: (json['statusHistory'] as List)
            .map((e) => StatusHistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        attachments: (json['attachments'] as List)
            .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
