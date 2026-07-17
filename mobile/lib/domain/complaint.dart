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

  final ComplaintStatus? fromStatus;
  final ComplaintStatus toStatus;
  final String? note;
  final String changedBy;
  final DateTime changedAt;

  factory StatusHistoryEntry.fromJson(Map<String, dynamic> json) => StatusHistoryEntry(
        fromStatus: json['fromStatus'] == null
            ? null
            : ComplaintStatus.fromJson(json['fromStatus'] as String),
        toStatus: ComplaintStatus.fromJson(json['toStatus'] as String),
        note: json['note'] as String?,
        changedBy: json['changedBy'] as String,
        changedAt: DateTime.parse(json['changedAt'] as String),
      );
}

/// Named `ComplaintFeedback` (not `Feedback`) to avoid colliding with
/// Flutter's own `Feedback` class (haptic/acoustic feedback helper in
/// material.dart).
class ComplaintFeedback {
  const ComplaintFeedback({required this.rating, this.comment, required this.createdAt});

  final int rating;
  final String? comment;
  final DateTime createdAt;

  factory ComplaintFeedback.fromJson(Map<String, dynamic> json) => ComplaintFeedback(
        rating: json['rating'] as int,
        comment: json['comment'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class ComplaintSummary {
  const ComplaintSummary({
    required this.id,
    required this.complaintNumber,
    required this.title,
    required this.category,
    required this.status,
    required this.severity,
    required this.createdBy,
    this.assignedTo,
    required this.createdAt,
    required this.updatedAt,
    this.assignedAt,
  });

  final int id;
  final String complaintNumber;
  final String title;
  final String category;
  final ComplaintStatus status;
  final ComplaintSeverity severity;
  final String createdBy;
  final String? assignedTo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? assignedAt;

  bool get isOverdue =>
      (status == ComplaintStatus.assigned || status == ComplaintStatus.inProgress) &&
      DateTime.now().difference(assignedAt ?? createdAt) > severity.slaDuration;

  /// The real backend's `TicketSummaryDto` has no `assignedAt`/severity-SLA
  /// concept, so those fall back to sensible defaults when parsed from a
  /// real API response instead of the mock backend.
  factory ComplaintSummary.fromJson(Map<String, dynamic> json) => ComplaintSummary(
        id: json['id'] as int,
        complaintNumber: json['ticketNumber'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        status: ComplaintStatus.fromJson(json['status'] as String),
        severity: ComplaintSeverity.fromJson(json['priority'] as String),
        createdBy: json['createdBy'] as String,
        assignedTo: json['assignedTo'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        assignedAt: json['assignedAt'] == null ? null : DateTime.parse(json['assignedAt'] as String),
      );
}

class Complaint {
  const Complaint({
    required this.id,
    required this.complaintNumber,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.severity,
    required this.createdBy,
    required this.createdById,
    this.assignedTo,
    this.assignedToId,
    this.department,
    required this.createdAt,
    required this.updatedAt,
    this.assignedAt,
    this.resolvedAt,
    this.closedAt,
    this.rejectionReason,
    this.feedback,
    required this.statusHistory,
    required this.attachments,
  });

  final int id;
  final String complaintNumber;
  final String title;
  final String description;
  final String category;
  final ComplaintStatus status;
  final ComplaintSeverity severity;
  final String createdBy;
  final int createdById;
  final String? assignedTo;
  final int? assignedToId;
  final String? department;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// When a handler (self-assigned or manually assigned) first took
  /// ownership of this complaint. Also the baseline the SLA countdown is
  /// measured from — see [isOverdue].
  final DateTime? assignedAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;

  /// Set only when [status] is [ComplaintStatus.rejected] (declined on the
  /// web dashboard during the Critical-severity approval step).
  final String? rejectionReason;
  final ComplaintFeedback? feedback;
  final List<StatusHistoryEntry> statusHistory;
  final List<Attachment> attachments;

  bool get isOverdue =>
      (status == ComplaintStatus.assigned || status == ComplaintStatus.inProgress) &&
      DateTime.now().difference(assignedAt ?? createdAt) > severity.slaDuration;

  factory Complaint.fromJson(Map<String, dynamic> json) => Complaint(
        id: json['id'] as int,
        complaintNumber: json['ticketNumber'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        category: json['category'] as String,
        status: ComplaintStatus.fromJson(json['status'] as String),
        severity: ComplaintSeverity.fromJson(json['priority'] as String),
        createdBy: json['createdBy'] as String,
        createdById: json['createdById'] as int,
        assignedTo: json['assignedTo'] as String?,
        assignedToId: json['assignedToId'] as int?,
        department: json['department'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        assignedAt: json['assignedAt'] == null
            ? _assignedAtFromHistory(json)
            : DateTime.parse(json['assignedAt'] as String),
        resolvedAt: json['resolvedAt'] == null ? null : DateTime.parse(json['resolvedAt'] as String),
        closedAt: json['closedAt'] == null ? null : DateTime.parse(json['closedAt'] as String),
        rejectionReason: json['rejectionReason'] as String?,
        feedback: json['feedback'] == null
            ? null
            : ComplaintFeedback.fromJson(json['feedback'] as Map<String, dynamic>),
        statusHistory: (json['statusHistory'] as List)
            .map((e) => StatusHistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        attachments: (json['attachments'] as List)
            .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// The real backend's `TicketDto` has no `assignedAt` field — recover a
  /// reasonable value from the status history's first transition into
  /// `Assigned` so real-API complaints still show an assigned time.
  static DateTime? _assignedAtFromHistory(Map<String, dynamic> json) {
    final history = json['statusHistory'] as List?;
    if (history == null) return null;
    for (final entry in history) {
      final map = entry as Map<String, dynamic>;
      if ((map['toStatus'] as String?) == 'Assigned') {
        return DateTime.parse(map['changedAt'] as String);
      }
    }
    return null;
  }
}
