namespace Ogdcl.Domain;

public enum UserRole
{
    Employee = 0,
    Handler = 1,
    Security = 2,
    Admin = 3,
}

public enum TicketStatus
{
    Open = 0,
    Assigned = 1,
    InProgress = 2,
    Resolved = 3,
    Closed = 4,
}

public enum TicketPriority
{
    Low = 0,
    Medium = 1,
    High = 2,
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
}
