using System.Security.Cryptography;
using Microsoft.EntityFrameworkCore;
using Ogdcl.Application.Common;
using Ogdcl.Domain.Entities;

namespace Ogdcl.Application.Auth;

public class AuthService
{
    private readonly IAppDbContext _db;
    private readonly IAuthProvider _authProvider;
    private readonly IJwtTokenService _jwt;
    private readonly int _refreshTokenDays;

    public AuthService(IAppDbContext db, IAuthProvider authProvider, IJwtTokenService jwt, int refreshTokenDays = 7)
    {
        _db = db;
        _authProvider = authProvider;
        _jwt = jwt;
        _refreshTokenDays = refreshTokenDays;
    }

    public async Task<AuthResponse> LoginAsync(LoginRequest request, CancellationToken ct = default)
    {
        var external = await _authProvider.ValidateCredentialsAsync(request.Username.Trim(), request.Password, ct)
            ?? throw new UnauthorizedException("Invalid username or password.");

        var normalized = external.Username.ToLowerInvariant();
        var user = await _db.Users
            .Include(u => u.Department)
            .FirstOrDefaultAsync(u => u.Username.ToLower() == normalized, ct);

        if (user is null)
        {
            // First login of an AD-backed account: sync it into the local store.
            var department = external.DepartmentName is null
                ? null
                : await _db.Departments.FirstOrDefaultAsync(d => d.Name == external.DepartmentName, ct);

            user = new User
            {
                Username = external.Username,
                DisplayName = external.DisplayName,
                Email = external.Email,
                Role = external.Role,
                DepartmentId = department?.Id,
                Department = department,
            };
            _db.Users.Add(user);
            await _db.SaveChangesAsync(ct);
        }

        if (!user.IsActive)
            throw new UnauthorizedException("This account has been deactivated.");

        return await IssueTokensAsync(user, ct);
    }

    public async Task<AuthResponse> RefreshAsync(RefreshRequest request, CancellationToken ct = default)
    {
        var stored = await _db.RefreshTokens
            .Include(t => t.User).ThenInclude(u => u.Department)
            .FirstOrDefaultAsync(t => t.Token == request.RefreshToken, ct);

        if (stored is null || !stored.IsUsable || !stored.User.IsActive)
            throw new UnauthorizedException("Refresh token is invalid or expired. Please log in again.");

        stored.RevokedAt = DateTime.UtcNow;
        return await IssueTokensAsync(stored.User, ct);
    }

    public async Task LogoutAsync(RefreshRequest request, CancellationToken ct = default)
    {
        var stored = await _db.RefreshTokens.FirstOrDefaultAsync(t => t.Token == request.RefreshToken, ct);
        if (stored is not null && stored.RevokedAt is null)
        {
            stored.RevokedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync(ct);
        }
    }

    public async Task<UserDto> GetProfileAsync(int userId, CancellationToken ct = default)
    {
        var user = await _db.Users.Include(u => u.Department).FirstOrDefaultAsync(u => u.Id == userId, ct)
            ?? throw new NotFoundException("User not found.");
        return ToDto(user);
    }

    private async Task<AuthResponse> IssueTokensAsync(User user, CancellationToken ct)
    {
        var (accessToken, expiresAt) = _jwt.CreateAccessToken(user);

        var refresh = new RefreshToken
        {
            UserId = user.Id,
            Token = Convert.ToBase64String(RandomNumberGenerator.GetBytes(48)),
            ExpiresAt = DateTime.UtcNow.AddDays(_refreshTokenDays),
        };
        _db.RefreshTokens.Add(refresh);
        await _db.SaveChangesAsync(ct);

        return new AuthResponse(accessToken, expiresAt, refresh.Token, ToDto(user));
    }

    private static UserDto ToDto(User u) =>
        new(u.Id, u.Username, u.DisplayName, u.Email, u.Role, u.Department?.Name);
}
