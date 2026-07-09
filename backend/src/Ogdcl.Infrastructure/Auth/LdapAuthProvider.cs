using Ogdcl.Application.Auth;

namespace Ogdcl.Infrastructure.Auth;

/// <summary>
/// Production credential authority: binds against OGDCL Active Directory over
/// LDAP and maps AD groups to application roles.
///
/// Deliberately unimplemented until OGDCL provides the AD endpoint, a service
/// account, and the group structure export (implementation plan, Section 13).
/// The planned implementation uses Novell.Directory.Ldap so it runs inside
/// Linux containers. Selecting this provider is configuration only:
/// "Auth:Provider": "Ldap".
/// </summary>
public class LdapAuthProvider : IAuthProvider
{
    public Task<ExternalUser?> ValidateCredentialsAsync(string username, string password, CancellationToken ct = default) =>
        throw new NotSupportedException(
            "LDAP authentication is not configured yet. Set Auth:Provider to 'Dev' until OGDCL AD details are available.");
}
