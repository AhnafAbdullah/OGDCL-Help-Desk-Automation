namespace Ogdcl.Application.Visits;

public enum OtpVerifyStatus
{
    Success,
    Invalid,
    Expired,
    LockedOut,
}

public record OtpVerification(OtpVerifyStatus Status, int AttemptsRemaining);

public record OtpOptions(TimeSpan Ttl, int MaxAttempts);

/// <summary>
/// Time-limited, single-use OTP storage. The dev implementation is in-memory;
/// the interface matches a Redis-backed implementation (SETEX + attempt
/// counter) planned for deployment.
/// </summary>
public interface IOtpStore
{
    string Generate(string key, TimeSpan ttl, int maxAttempts);
    OtpVerification Verify(string key, string code);
    void Remove(string key);
}
