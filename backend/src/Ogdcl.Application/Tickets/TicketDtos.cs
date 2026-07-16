using Ogdcl.Domain;

namespace Ogdcl.Application.Tickets;

public record CreateTicketRequest(int CategoryId, string Title, string Description, TicketPriority Severity = TicketPriority.Medium);

public record UpdateTicketStatusRequest(TicketStatus Status, string? Note);

public record AssignTicketRequest(int HandlerId);

public record RejectRequest(string? Reason);

public record TicketFeedbackRequest(int Rating, string? Comment);

public record AttachmentDto(int Id, string FileName, string ContentType, long SizeBytes, DateTime UploadedAt);

public record StatusHistoryDto(TicketStatus? FromStatus, TicketStatus ToStatus, string? Note, string ChangedBy, DateTime ChangedAt);

public record FeedbackDto(int Rating, string? Comment, DateTime CreatedAt);

public record TicketDto(
    int Id,
    string TicketNumber,
    string Title,
    string Description,
    string Category,
    TicketStatus Status,
    TicketPriority Severity,
    bool IsOverdue,
    DateTime? EscalationDueAt,
    string CreatedBy,
    int CreatedById,
    string? AssignedTo,
    int? AssignedToId,
    string? Department,
    int? DepartmentId,
    string? RecommendedHandler,
    int? RecommendedHandlerId,
    DateTime CreatedAt,
    DateTime UpdatedAt,
    DateTime? ResolvedAt,
    DateTime? ClosedAt,
    FeedbackDto? Feedback,
    List<StatusHistoryDto> StatusHistory,
    List<AttachmentDto> Attachments);

public record TicketSummaryDto(
    int Id,
    string TicketNumber,
    string Title,
    string Category,
    TicketStatus Status,
    TicketPriority Severity,
    bool IsOverdue,
    string CreatedBy,
    string? AssignedTo,
    string? Department,
    DateTime CreatedAt,
    DateTime UpdatedAt);

public record CategoryDto(int Id, string Name);

/// <summary>Per-handler workload/throughput, shown to admins.</summary>
public record HandlerStatDto(
    int HandlerId,
    string Handler,
    string? Department,
    int Solved,
    int Closed,
    int Active);
