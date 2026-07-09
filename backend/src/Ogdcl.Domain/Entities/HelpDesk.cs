namespace Ogdcl.Domain.Entities;

public class ComplaintCategory
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public bool IsActive { get; set; } = true;
}

/// <summary>
/// Data-driven routing: maps a complaint category to the department that
/// handles it, so OGDCL's final category mapping can be configured from the
/// admin dashboard without code changes.
/// </summary>
public class AssignmentRule
{
    public int Id { get; set; }
    public int CategoryId { get; set; }
    public ComplaintCategory Category { get; set; } = null!;
    public int DepartmentId { get; set; }
    public Department Department { get; set; } = null!;
    public TicketPriority DefaultPriority { get; set; } = TicketPriority.Medium;
}

public class Ticket
{
    public int Id { get; set; }
    public string TicketNumber { get; set; } = null!;
    public string Title { get; set; } = null!;
    public string Description { get; set; } = null!;
    public int CategoryId { get; set; }
    public ComplaintCategory Category { get; set; } = null!;
    public int CreatedById { get; set; }
    public User CreatedBy { get; set; } = null!;
    public int? DepartmentId { get; set; }
    public Department? Department { get; set; }
    public int? AssignedToId { get; set; }
    public User? AssignedTo { get; set; }
    public TicketPriority Priority { get; set; } = TicketPriority.Medium;
    public TicketStatus Status { get; set; } = TicketStatus.Open;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? ResolvedAt { get; set; }
    public DateTime? ClosedAt { get; set; }
    public bool IsDeleted { get; set; }

    public List<TicketAttachment> Attachments { get; set; } = [];
    public List<TicketStatusHistory> StatusHistory { get; set; } = [];
    public TicketFeedback? Feedback { get; set; }
}

public class TicketAttachment
{
    public int Id { get; set; }
    public int TicketId { get; set; }
    public Ticket Ticket { get; set; } = null!;
    public string FileName { get; set; } = null!;
    public string ContentType { get; set; } = null!;
    public long SizeBytes { get; set; }
    public string StoredPath { get; set; } = null!;
    public int UploadedById { get; set; }
    public DateTime UploadedAt { get; set; } = DateTime.UtcNow;
}

/// <summary>Append-only audit trail of every status change on a ticket.</summary>
public class TicketStatusHistory
{
    public int Id { get; set; }
    public int TicketId { get; set; }
    public Ticket Ticket { get; set; } = null!;
    public TicketStatus? FromStatus { get; set; }
    public TicketStatus ToStatus { get; set; }
    public string? Note { get; set; }
    public int ChangedById { get; set; }
    public User ChangedBy { get; set; } = null!;
    public DateTime ChangedAt { get; set; } = DateTime.UtcNow;
}

public class TicketFeedback
{
    public int Id { get; set; }
    public int TicketId { get; set; }
    public Ticket Ticket { get; set; } = null!;
    public int Rating { get; set; }
    public string? Comment { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
