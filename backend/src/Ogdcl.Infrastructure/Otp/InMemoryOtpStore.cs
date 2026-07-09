using System.Collections.Concurrent;
using System.Security.Cryptography;
using Ogdcl.Application.Visits;

namespace Ogdcl.Infrastructure.Otp;

/// <summary>
/// Dev/demo OTP store. Codes are single-use, expire after their TTL, and lock
/// after too many wrong attempts. The Redis implementation planned for
/// deployment keeps the same contract.
/// </summary>
public class InMemoryOtpStore : IOtpStore
{
    private sealed record Entry(string Code, DateTimeOffset ExpiresAt, int AttemptsRemaining);

    private readonly ConcurrentDictionary<string, Entry> _entries = new();
    private readonly TimeProvider _time;

    public InMemoryOtpStore(TimeProvider time)
    {
        _time = time;
    }

    public string Generate(string key, TimeSpan ttl, int maxAttempts)
    {
        var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
        _entries[key] = new Entry(code, _time.GetUtcNow().Add(ttl), maxAttempts);
        return code;
    }

    public OtpVerification Verify(string key, string code)
    {
        if (!_entries.TryGetValue(key, out var entry))
            return new OtpVerification(OtpVerifyStatus.Expired, 0);

        if (entry.ExpiresAt <= _time.GetUtcNow())
        {
            _entries.TryRemove(key, out _);
            return new OtpVerification(OtpVerifyStatus.Expired, 0);
        }

        if (entry.Code == code)
        {
            _entries.TryRemove(key, out _); // single-use
            return new OtpVerification(OtpVerifyStatus.Success, entry.AttemptsRemaining);
        }

        var remaining = entry.AttemptsRemaining - 1;
        if (remaining <= 0)
        {
            _entries.TryRemove(key, out _);
            return new OtpVerification(OtpVerifyStatus.LockedOut, 0);
        }

        _entries[key] = entry with { AttemptsRemaining = remaining };
        return new OtpVerification(OtpVerifyStatus.Invalid, remaining);
    }

    public void Remove(string key) => _entries.TryRemove(key, out _);
}
