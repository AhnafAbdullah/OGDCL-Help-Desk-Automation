using Ogdcl.Domain;
using Ogdcl.Domain.Entities;

namespace Ogdcl.Application.Auth;

/// <summary>
/// A user identity as confirmed by the credential authority. Production uses an
/// LDAP bind against OGDCL Active Directory; development uses the seeded local
/// user store. Switching providers is configuration only ("Auth:Provider").
/// </summary>
public record ExternalUser(
    string Username,
    string DisplayName,
    string Email,
    UserRole Role,
    string? DepartmentName);

public interface IAuthProvider
{
    /// <summary>Returns the confirmed identity, or null when credentials are invalid.</summary>
    Task<ExternalUser?> ValidateCredentialsAsync(string username, string password, CancellationToken ct = default);
}

public interface IPasswordHasher
{
    string Hash(string password);
    bool Verify(string password, string hash);
}

public interface IJwtTokenService
{
    (string Token, DateTime ExpiresAtUtc) CreateAccessToken(User user);
}

public record LoginRequest(string Username, string Password);

public record RefreshRequest(string RefreshToken);

public record UserDto(int Id, string Username, string DisplayName, string Email, UserRole Role, string? Department);

public record AuthResponse(
    string AccessToken,
    DateTime ExpiresAtUtc,
    string RefreshToken,
    UserDto User);
