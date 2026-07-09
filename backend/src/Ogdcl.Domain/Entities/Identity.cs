namespace Ogdcl.Domain.Entities;

/// <summary>
/// Mirrors an OGDCL Active Directory account. In production users are synced on
/// first LDAP login and PasswordHash stays null; the dev auth provider stores a
/// local PBKDF2 hash so the team can work without AD access.
/// </summary>
public class User
{
    public int Id { get; set; }
    public string Username { get; set; } = null!;
    public string DisplayName { get; set; } = null!;
    public string Email { get; set; } = string.Empty;
    public UserRole Role { get; set; }
    public int? DepartmentId { get; set; }
    public Department? Department { get; set; }
    public string? PasswordHash { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public class Department
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
}

public class RefreshToken
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public User User { get; set; } = null!;
    public string Token { get; set; } = null!;
    public DateTime ExpiresAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? RevokedAt { get; set; }

    public bool IsUsable => RevokedAt is null && ExpiresAt > DateTime.UtcNow;
}
