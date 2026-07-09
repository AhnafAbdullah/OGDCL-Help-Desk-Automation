using Ogdcl.Domain;

namespace Ogdcl.Application.Visits;

public record RegisterVisitRequest(
    string FullName,
    string Cnic,
    string ContactNumber,
    string Purpose,
    DateTime ExpectedArrival,
    List<int> ZoneIds);

public record VerifyOtpRequest(string Code);

public record IssueCardRequest(string CardUid);

public record ZoneDto(int Id, string Name, bool IsRestricted);

public record VisitDto(
    int Id,
    string VisitorName,
    string Cnic,
    string ContactNumber,
    string Host,
    int HostId,
    string Purpose,
    DateTime ExpectedArrival,
    VisitStatus Status,
    DateTime CreatedAt,
    DateTime? ArrivedAt,
    DateTime? DepartedAt,
    string? CardUid,
    List<ZoneDto> Zones);
