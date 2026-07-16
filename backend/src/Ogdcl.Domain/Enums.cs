namespace Ogdcl.Domain;

public enum UserRole
{
    Employee = 0,
    Handler = 1,
    Security = 2,
    /// <summary>Administers a single department: approves urgent complaints and
    /// monitors that department's handlers.</summary>
    FloorAdmin = 3,
    /// <summary>Full oversight across all departments plus global settings.</summary>
    SuperAdmin = 4,
}

public enum TicketStatus
{
    /// <summary>Urgent complaint awaiting a floor/super admin's approval.</summary>
    PendingApproval = 0,
    /// <summary>Approved (or non-urgent): available for a handler to accept.</summary>
    Open = 1,
    /// <summary>A handler has accepted and owns it.</summary>
    Assigned = 2,
    InProgress = 3,
    Resolved = 4,
    Closed = 5,
    /// <summary>An urgent complaint an admin declined to approve.</summary>
    Rejected = 6,
}

/// <summary>Complaint severity (shown in the UI as "severity"). Critical is only
/// ever reached by auto-escalation, never chosen by the employee.</summary>
public enum TicketPriority
{
    Low = 0,
    Medium = 1,
    Urgent = 2,
    Critical = 3,
}

public enum VisitStatus
{
    Registered = 0,
    Arrived = 1,
    Closed = 2,
    Cancelled = 3,
}

public enum NotificationType
{
    TicketAssigned = 0,
    TicketStatusChanged = 1,
    TicketClosed = 2,
    FeedbackRequested = 3,
    VisitorOtp = 4,
    VisitorArrived = 5,
    VisitorDeparted = 6,
    System = 7,
    NewComplaint = 8,
    ApprovalRequired = 9,
    TicketAccepted = 10,
    TicketRejected = 11,
    TicketEscalated = 12,
}
