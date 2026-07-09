using Ogdcl.Application.Visits;
using Ogdcl.Infrastructure.Otp;

namespace Ogdcl.Tests;

public class OtpStoreTests
{
    private readonly TestTimeProvider _time = new();
    private readonly InMemoryOtpStore _store;

    public OtpStoreTests()
    {
        _store = new InMemoryOtpStore(_time);
    }

    [Fact]
    public void CorrectCode_Succeeds_AndIsSingleUse()
    {
        var code = _store.Generate("visit:1", TimeSpan.FromHours(1), 5);

        var first = _store.Verify("visit:1", code);
        Assert.Equal(OtpVerifyStatus.Success, first.Status);

        // The code must not be reusable after a successful verification.
        var second = _store.Verify("visit:1", code);
        Assert.Equal(OtpVerifyStatus.Expired, second.Status);
    }

    [Fact]
    public void WrongCode_CountsDownAttempts_ThenLocksOut()
    {
        var code = _store.Generate("visit:1", TimeSpan.FromHours(1), 3);
        var wrong = code == "000000" ? "111111" : "000000";

        Assert.Equal(OtpVerifyStatus.Invalid, _store.Verify("visit:1", wrong).Status);
        Assert.Equal(OtpVerifyStatus.Invalid, _store.Verify("visit:1", wrong).Status);
        Assert.Equal(OtpVerifyStatus.LockedOut, _store.Verify("visit:1", wrong).Status);

        // After lockout, even the correct code no longer works.
        Assert.Equal(OtpVerifyStatus.Expired, _store.Verify("visit:1", code).Status);
    }

    [Fact]
    public void ExpiredCode_IsRejected()
    {
        var code = _store.Generate("visit:1", TimeSpan.FromHours(1), 5);

        _time.Now = _time.Now.AddHours(2);

        Assert.Equal(OtpVerifyStatus.Expired, _store.Verify("visit:1", code).Status);
    }

    [Fact]
    public void Remove_InvalidatesCode()
    {
        var code = _store.Generate("visit:1", TimeSpan.FromHours(1), 5);
        _store.Remove("visit:1");

        Assert.Equal(OtpVerifyStatus.Expired, _store.Verify("visit:1", code).Status);
    }
}
