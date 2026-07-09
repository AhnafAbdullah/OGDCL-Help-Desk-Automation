using Microsoft.EntityFrameworkCore;
using Ogdcl.Application.Auth;
using Ogdcl.Application.Common;

namespace Ogdcl.Infrastructure.Auth;

/// <summary>
/// Validates credentials against the seeded local user store so development
/// and demos work without access to OGDCL's Active Directory.
/// </summary>
public class DevAuthProvider : IAuthProvider
{
    private readonly IAppDbContext _db;
    private readonly IPasswordHasher _hasher;

    public DevAuthProvider(IAppDbContext db, IPasswordHasher hasher)
    {
        _db = db;
        _hasher = hasher;
    }

    public async Task<ExternalUser?> ValidateCredentialsAsync(string username, string password, CancellationToken ct = default)
    {
        var normalized = username.ToLowerInvariant();
        var user = await _db.Users
            .Include(u => u.Department)
            .FirstOrDefaultAsync(u => u.Username.ToLower() == normalized, ct);

        if (user?.PasswordHash is null || !user.IsActive)
            return null;
        if (!_hasher.Verify(password, user.PasswordHash))
            return null;

        return new ExternalUser(user.Username, user.DisplayName, user.Email, user.Role, user.Department?.Name);
    }
}
