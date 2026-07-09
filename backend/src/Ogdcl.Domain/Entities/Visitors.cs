namespace Ogdcl.Domain.Entities;

public class Visitor
{
    public int Id { get; set; }
    public string FullName { get; set; } = null!;
    public string Cnic { get; set; } = null!;
    public string ContactNumber { get; set; } = null!;
    public List<VisitRequest> Visits { get; set; } = [];
}

public class VisitRequest
{
    public int Id { get; set; }
    public int VisitorId { get; set; }
    public Visitor Visitor { get; set; } = null!;
    public int HostId { get; set; }
    public User Host { get; set; } = null!;
    public string Purpose { get; set; } = null!;
    public DateTime ExpectedArrival { get; set; }
    public VisitStatus Status { get; set; } = VisitStatus.Registered;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? ArrivedAt { get; set; }
    public DateTime? DepartedAt { get; set; }

    // The card stays linked after closure for the audit trail; a card is
    // considered "in use" only while its visit is in the Arrived state.
    public int? CardId { get; set; }
    public RfidCard? Card { get; set; }

    public List<VisitZonePermission> ZonePermissions { get; set; } = [];
}

public class Zone
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public bool IsRestricted { get; set; }
}

public class VisitZonePermission
{
    public int VisitRequestId { get; set; }
    public VisitRequest VisitRequest { get; set; } = null!;
    public int ZoneId { get; set; }
    public Zone Zone { get; set; } = null!;
}

public class RfidCard
{
    public int Id { get; set; }
    public string CardUid { get; set; } = null!;
    public bool IsActive { get; set; }
}
