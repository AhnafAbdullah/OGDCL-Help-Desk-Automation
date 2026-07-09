using Ogdcl.Application.Common;
using Ogdcl.Application.Visits;
using Ogdcl.Domain;

namespace Ogdcl.Tests;

public class VisitServiceTests : IDisposable
{
    private readonly TestFixture _fx = new();
    private readonly VisitService _service;

    public VisitServiceTests()
    {
        _service = new VisitService(_fx.Db, _fx.Notifier, _fx.OtpStore,
            new OtpOptions(TimeSpan.FromHours(24), MaxAttempts: 3));
    }

    public void Dispose() => _fx.Dispose();

    private Task<VisitDto> RegisterVisit() =>
        _service.RegisterAsync(_fx.Employee.Id, new RegisterVisitRequest(
            "Ali Raza", "35202-1234567-1", "0300-1234567", "Vendor meeting",
            DateTime.UtcNow.AddHours(2), [_fx.Lobby.Id]));

    [Fact]
    public async Task Register_CreatesVisit_GeneratesOtp_NotifiesGuardAndHost()
    {
        var visit = await RegisterVisit();

        Assert.Equal(VisitStatus.Registered, visit.Status);
        Assert.NotNull(_fx.OtpStore.LastCode);

        // Guard receives the OTP; host receives a confirmation.
        Assert.Contains(_fx.Channel.Pushed, p =>
            p.UserId == _fx.Guard.Id &&
            p.Notification.Type == NotificationType.VisitorOtp &&
            p.Notification.Body.Contains(_fx.OtpStore.LastCode!));
        Assert.Contains(_fx.Channel.Pushed, p => p.UserId == _fx.Employee.Id);
    }

    [Fact]
    public async Task Register_WithUnknownZone_IsRejected()
    {
        await Assert.ThrowsAsync<AppValidationException>(() =>
            _service.RegisterAsync(_fx.Employee.Id, new RegisterVisitRequest(
                "Ali Raza", "35202-1234567-1", "0300-1234567", "Meeting",
                DateTime.UtcNow.AddHours(1), [9999])));
    }

    [Fact]
    public async Task VerifyOtp_CorrectCode_MarksArrived_AndNotifiesHost()
    {
        var visit = await RegisterVisit();

        var verified = await _service.VerifyOtpAsync(visit.Id, _fx.Guard.Id,
            new VerifyOtpRequest(_fx.OtpStore.LastCode!));

        Assert.Equal(VisitStatus.Arrived, verified.Status);
        Assert.NotNull(verified.ArrivedAt);
        Assert.Contains(_fx.Channel.Pushed, p =>
            p.UserId == _fx.Employee.Id && p.Notification.Type == NotificationType.VisitorArrived);
    }

    [Fact]
    public async Task VerifyOtp_WrongCode_ReportsRemainingAttempts()
    {
        var visit = await RegisterVisit();
        var wrong = _fx.OtpStore.LastCode == "000000" ? "111111" : "000000";

        var ex = await Assert.ThrowsAsync<AppValidationException>(() =>
            _service.VerifyOtpAsync(visit.Id, _fx.Guard.Id, new VerifyOtpRequest(wrong)));

        Assert.Contains("2 attempt(s) remaining", ex.Message);
    }

    [Fact]
    public async Task FullLifecycle_CardIsReusable_AfterVisitCloses()
    {
        var visit = await RegisterVisit();
        await _service.VerifyOtpAsync(visit.Id, _fx.Guard.Id, new VerifyOtpRequest(_fx.OtpStore.LastCode!));

        var withCard = await _service.IssueCardAsync(visit.Id, _fx.Guard.Id, new IssueCardRequest("CARD-001"));
        Assert.Equal("CARD-001", withCard.CardUid);

        var closed = await _service.CloseAsync(visit.Id, _fx.Guard.Id);
        Assert.Equal(VisitStatus.Closed, closed.Status);
        Assert.NotNull(closed.DepartedAt);

        // A second visit can reuse the returned card.
        var next = await _service.RegisterAsync(_fx.Employee.Id, new RegisterVisitRequest(
            "Sara Khan", "35202-7654321-2", "0301-7654321", "Interview",
            DateTime.UtcNow.AddHours(3), [_fx.Lobby.Id]));
        await _service.VerifyOtpAsync(next.Id, _fx.Guard.Id, new VerifyOtpRequest(_fx.OtpStore.LastCode!));
        var reissued = await _service.IssueCardAsync(next.Id, _fx.Guard.Id, new IssueCardRequest("CARD-001"));

        Assert.Equal("CARD-001", reissued.CardUid);
    }

    [Fact]
    public async Task IssueCard_WhileCardActiveOnAnotherVisit_IsRejected()
    {
        var first = await RegisterVisit();
        await _service.VerifyOtpAsync(first.Id, _fx.Guard.Id, new VerifyOtpRequest(_fx.OtpStore.LastCode!));
        await _service.IssueCardAsync(first.Id, _fx.Guard.Id, new IssueCardRequest("CARD-001"));

        var second = await _service.RegisterAsync(_fx.Employee.Id, new RegisterVisitRequest(
            "Sara Khan", "35202-7654321-2", "0301-7654321", "Interview",
            DateTime.UtcNow.AddHours(3), [_fx.Lobby.Id]));
        await _service.VerifyOtpAsync(second.Id, _fx.Guard.Id, new VerifyOtpRequest(_fx.OtpStore.LastCode!));

        await Assert.ThrowsAsync<AppValidationException>(() =>
            _service.IssueCardAsync(second.Id, _fx.Guard.Id, new IssueCardRequest("CARD-001")));
    }

    [Fact]
    public async Task IssueCard_BeforeOtpVerification_IsRejected()
    {
        var visit = await RegisterVisit();

        await Assert.ThrowsAsync<AppValidationException>(() =>
            _service.IssueCardAsync(visit.Id, _fx.Guard.Id, new IssueCardRequest("CARD-001")));
    }

    [Fact]
    public async Task Cancel_ByNonHost_IsForbidden()
    {
        var visit = await RegisterVisit();

        await Assert.ThrowsAsync<ForbiddenException>(() =>
            _service.CancelAsync(visit.Id, _fx.Guard.Id));
    }
}
