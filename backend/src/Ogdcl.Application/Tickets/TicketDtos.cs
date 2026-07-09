using Ogdcl.Domain;

namespace Ogdcl.Application.Tickets;

public record CreateTicketRequest(int CategoryId, string Title, string Description);

public record UpdateTicketStatusRequest(TicketStatus Status, string? Note);

public record AssignTicketRequest(int HandlerId);

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
    TicketPriority Priority,
    string CreatedBy,
    int CreatedById,
    string? AssignedTo,
    int? AssignedToId,
    string? Department,
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
    TicketPriority Priority,
    string CreatedBy,
    string? AssignedTo,
    DateTime CreatedAt,
    DateTime UpdatedAt);

public record CategoryDto(int Id, string Name);
