using Microsoft.EntityFrameworkCore;
using Ogdcl.Application.Common;
using Ogdcl.Application.Notifications;
using Ogdcl.Domain;
using Ogdcl.Domain.Entities;

namespace Ogdcl.Application.Visits;

public class VisitService
{
    private readonly IAppDbContext _db;
    private readonly INotifier _notifier;
    private readonly IOtpStore _otpStore;
    private readonly OtpOptions _otpOptions;

    public VisitService(IAppDbContext db, INotifier notifier, IOtpStore otpStore, OtpOptions otpOptions)
    {
        _db = db;
        _notifier = notifier;
        _otpStore = otpStore;
        _otpOptions = otpOptions;
    }

    public async Task<VisitDto> RegisterAsync(int hostId, RegisterVisitRequest request, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(request.FullName))
            throw new AppValidationException("Visitor name is required.");
        if (string.IsNullOrWhiteSpace(request.Cnic))
            throw new AppValidationException("CNIC is required.");
        if (string.IsNullOrWhiteSpace(request.Purpose))
            throw new AppValidationException("Purpose of visit is required.");
        if (request.ExpectedArrival < DateTime.UtcNow.AddHours(-1))
            throw new AppValidationException("Expected arrival cannot be in the past.");

        var zoneIds = request.ZoneIds?.Distinct().ToList() ?? [];
        var zones = await _db.Zones.Where(z => zoneIds.Contains(z.Id)).ToListAsync(ct);
        if (zones.Count != zoneIds.Count)
            throw new AppValidationException("One or more selected zones do not exist.");

        var host = await _db.Users.FirstOrDefaultAsync(u => u.Id == hostId, ct)
            ?? throw new UnauthorizedException("Unknown user.");

        var cnic = request.Cnic.Trim();
        var visitor = await _db.Visitors.FirstOrDefaultAsync(v => v.Cnic == cnic, ct);
        if (visitor is null)
        {
            visitor = new Visitor { Cnic = cnic };
            _db.Visitors.Add(visitor);
        }
        visitor.FullName = request.FullName.Trim();
        visitor.ContactNumber = request.ContactNumber?.Trim() ?? string.Empty;

        var visit = new VisitRequest
        {
            Visitor = visitor,
            HostId = hostId,
            Purpose = request.Purpose.Trim(),
            ExpectedArrival = request.ExpectedArrival,
            ZonePermissions = zones.Select(z => new VisitZonePermission { ZoneId = z.Id }).ToList(),
        };
        _db.VisitRequests.Add(visit);
        await _db.SaveChangesAsync(ct);

        var otp = _otpStore.Generate(OtpKey(visit.Id), _otpOptions.Ttl, _otpOptions.MaxAttempts);

        // Per the approved scope, the OTP goes to the gate guards as a
        // notification; the guard types it in when the visitor arrives.
        await _notifier.NotifyRoleAsync(UserRole.Security, NotificationType.VisitorOtp,
            $"Visitor OTP: {visitor.FullName}",
            $"OTP {otp} — {visitor.FullName} (host: {host.DisplayName}), expected {visit.ExpectedArrival:HH:mm dd MMM}. " +
            $"Zones: {(zones.Count == 0 ? "none" : string.Join(", ", zones.Select(z => z.Name)))}.", ct);

        await _notifier.NotifyUsersAsync([hostId], NotificationType.System,
            "Visitor registered",
            $"{visitor.FullName} is registered for {visit.ExpectedArrival:HH:mm dd MMM}. Security has received the entry code.", ct);

        return await GetByIdAsync(visit.Id, hostId, ct);
    }

    public async Task<VisitDto> VerifyOtpAsync(int visitId, int guardId, VerifyOtpRequest request, CancellationToken ct = default)
    {
        var visit = await LoadVisitAsync(visitId, ct);
        if (visit.Status != VisitStatus.Registered)
            throw new AppValidationException($"This visit is {visit.Status} and cannot be verified.");

        var verification = _otpStore.Verify(OtpKey(visit.Id), request.Code?.Trim() ?? string.Empty);
        switch (verification.Status)
        {
            case OtpVerifyStatus.Invalid:
                throw new AppValidationException(
                    $"Incorrect code. {verification.AttemptsRemaining} attempt(s) remaining.");
            case OtpVerifyStatus.Expired:
                throw new AppValidationException(
                    "This code has expired or was never issued. Ask the host to resend the OTP.");
            case OtpVerifyStatus.LockedOut:
                throw new AppValidationException(
                    "Too many incorrect attempts. The code is locked; the host must resend the OTP.");
        }

        visit.Status = VisitStatus.Arrived;
        visit.ArrivedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        await _notifier.NotifyUsersAsync([visit.HostId], NotificationType.VisitorArrived,
            $"{visit.Visitor.FullName} has arrived",
            $"Your visitor was verified at the gate at {visit.ArrivedAt:HH:mm}.", ct);

        return await GetByIdAsync(visit.Id, guardId, ct);
    }

    public async Task<VisitDto> ResendOtpAsync(int visitId, int actorId, CancellationToken ct = default)
    {
        var actor = await _db.Users.FirstOrDefaultAsync(u => u.Id == actorId, ct)
            ?? throw new UnauthorizedException("Unknown user.");
        var visit = await LoadVisitAsync(visitId, ct);

        if (visit.HostId != actorId && actor.Role != UserRole.Admin)
            throw new ForbiddenException("Only the host or an admin can resend the OTP.");
        if (visit.Status != VisitStatus.Registered)
            throw new AppValidationException($"This visit is {visit.Status}; the OTP cannot be resent.");

        _otpStore.Remove(OtpKey(visit.Id));
        var otp = _otpStore.Generate(OtpKey(visit.Id), _otpOptions.Ttl, _otpOptions.MaxAttempts);

        await _notifier.NotifyRoleAsync(UserRole.Security, NotificationType.VisitorOtp,
            $"Visitor OTP (reissued): {visit.Visitor.FullName}",
            $"OTP {otp} — {visit.Visitor.FullName} (host: {visit.Host.DisplayName}), expected {visit.ExpectedArrival:HH:mm dd MMM}.", ct);

        return await GetByIdAsync(visit.Id, actorId, ct);
    }

    public async Task<VisitDto> IssueCardAsync(int visitId, int guardId, IssueCardRequest request, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(request.CardUid))
            throw new AppValidationException("Card UID is required.");

        var visit = await LoadVisitAsync(visitId, ct);
        if (visit.Status != VisitStatus.Arrived)
            throw new AppValidationException("A card can only be issued after the visitor's OTP is verified.");
        if (visit.CardId is not null)
            throw new AppValidationException("This visit already has a card issued.");

        var uid = request.CardUid.Trim();
        var card = await _db.RfidCards.FirstOrDefaultAsync(c => c.CardUid == uid, ct);
        if (card is null)
        {
            card = new RfidCard { CardUid = uid };
            _db.RfidCards.Add(card);
        }
        else if (card.IsActive)
        {
            throw new AppValidationException("This card is still active on another visit. Deactivate it first.");
        }

        card.IsActive = true;
        visit.Card = card;
        await _db.SaveChangesAsync(ct);

        return await GetByIdAsync(visit.Id, guardId, ct);
    }

    public async Task<VisitDto> CloseAsync(int visitId, int guardId, CancellationToken ct = default)
    {
        var visit = await LoadVisitAsync(visitId, ct);
        if (visit.Status != VisitStatus.Arrived)
            throw new AppValidationException($"This visit is {visit.Status} and cannot be closed at the gate.");

        visit.Status = VisitStatus.Closed;
        visit.DepartedAt = DateTime.UtcNow;
        if (visit.Card is not null)
            visit.Card.IsActive = false; // card is collected and becomes reusable

        _otpStore.Remove(OtpKey(visit.Id));
        await _db.SaveChangesAsync(ct);

        await _notifier.NotifyUsersAsync([visit.HostId], NotificationType.VisitorDeparted,
            $"{visit.Visitor.FullName} has left",
            $"Your visitor departed at {visit.DepartedAt:HH:mm}.", ct);

        return await GetByIdAsync(visit.Id, guardId, ct);
    }

    public async Task<VisitDto> CancelAsync(int visitId, int actorId, CancellationToken ct = default)
    {
        var actor = await _db.Users.FirstOrDefaultAsync(u => u.Id == actorId, ct)
            ?? throw new UnauthorizedException("Unknown user.");
        var visit = await LoadVisitAsync(visitId, ct);

        if (visit.HostId != actorId && actor.Role != UserRole.Admin)
            throw new ForbiddenException("Only the host or an admin can cancel a visit.");
        if (visit.Status != VisitStatus.Registered)
            throw new AppValidationException($"This visit is {visit.Status} and cannot be cancelled.");

        visit.Status = VisitStatus.Cancelled;
        _otpStore.Remove(OtpKey(visit.Id));
        await _db.SaveChangesAsync(ct);

        return await GetByIdAsync(visit.Id, actorId, ct);
    }

    public async Task<List<VisitDto>> GetMineAsync(int hostId, CancellationToken ct = default) =>
        (await LoadVisitsAsync(q => q.Where(v => v.HostId == hostId), ct)).Select(ToDto).ToList();

    public async Task<List<VisitDto>> GetPendingAsync(CancellationToken ct = default) =>
        (await LoadVisitsAsync(q => q.Where(v => v.Status == VisitStatus.Registered), ct)).Select(ToDto).ToList();

    public async Task<List<VisitDto>> GetActiveAsync(CancellationToken ct = default) =>
        (await LoadVisitsAsync(q => q.Where(v => v.Status == VisitStatus.Arrived), ct)).Select(ToDto).ToList();

    public async Task<VisitDto> GetByIdAsync(int visitId, int actorId, CancellationToken ct = default)
    {
        var actor = await _db.Users.FirstOrDefaultAsync(u => u.Id == actorId, ct)
            ?? throw new UnauthorizedException("Unknown user.");
        var visit = await LoadVisitAsync(visitId, ct);

        var canView = actor.Role is UserRole.Admin or UserRole.Security || visit.HostId == actorId;
        if (!canView)
            throw new ForbiddenException("You do not have access to this visit.");

        return ToDto(visit);
    }

    private static string OtpKey(int visitId) => $"visit:{visitId}";

    private async Task<VisitRequest> LoadVisitAsync(int visitId, CancellationToken ct) =>
        await VisitQuery(_db.VisitRequests).FirstOrDefaultAsync(v => v.Id == visitId, ct)
        ?? throw new NotFoundException("Visit not found.");

    private async Task<List<VisitRequest>> LoadVisitsAsync(
        Func<IQueryable<VisitRequest>, IQueryable<VisitRequest>> filter, CancellationToken ct) =>
        await filter(VisitQuery(_db.VisitRequests))
            .OrderByDescending(v => v.CreatedAt)
            .Take(200)
            .ToListAsync(ct);

    private static IQueryable<VisitRequest> VisitQuery(IQueryable<VisitRequest> query) =>
        query
            .Include(v => v.Visitor)
            .Include(v => v.Host)
            .Include(v => v.Card)
            .Include(v => v.ZonePermissions).ThenInclude(zp => zp.Zone);

    private static VisitDto ToDto(VisitRequest v) => new(
        v.Id, v.Visitor.FullName, v.Visitor.Cnic, v.Visitor.ContactNumber,
        v.Host.DisplayName, v.HostId, v.Purpose, v.ExpectedArrival, v.Status,
        v.CreatedAt, v.ArrivedAt, v.DepartedAt, v.Card?.CardUid,
        v.ZonePermissions.Select(zp => new ZoneDto(zp.Zone.Id, zp.Zone.Name, zp.Zone.IsRestricted)).ToList());
}
