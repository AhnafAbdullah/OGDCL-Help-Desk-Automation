using Microsoft.AspNetCore.Components.Server.ProtectedBrowserStorage;
using Ogdcl.Application.Auth;
using Ogdcl.Domain;

namespace Ogdcl.Web.Services;

/// <summary>Snapshot persisted to ProtectedLocalStorage so a page refresh keeps the session.</summary>
public record AuthSnapshot(string Token, UserDto User, DateTime ExpiresAtUtc);

/// <summary>
/// Per-circuit login state for the dashboard. The token is persisted in
/// ProtectedLocalStorage (not session storage) so it survives full page
/// reloads and tab restarts. Restoration is a single cached operation so the
/// layout and every page await the same result — avoiding a race where a
/// page's auth check runs before the session has been rehydrated.
/// </summary>
public class AuthState
{
    private const string StorageKey = "auth";

    private readonly ProtectedLocalStorage _storage;
    private Task? _restore;

    public AuthState(ProtectedLocalStorage storage)
    {
        _storage = storage;
    }

    public string? Token { get; private set; }
    public UserDto? User { get; private set; }

    public bool IsLoggedIn => Token is not null && User is not null;
    public bool IsSuperAdmin => User?.Role == UserRole.SuperAdmin;
    public bool IsFloorAdmin => User?.Role == UserRole.FloorAdmin;
    public bool IsAdmin => User?.Role is UserRole.FloorAdmin or UserRole.SuperAdmin;
    public bool IsSecurity => User?.Role is UserRole.Security or UserRole.SuperAdmin;
    public bool IsHandler => User?.Role == UserRole.Handler;
    public bool IsEmployee => User?.Role == UserRole.Employee;

    public event Action? Changed;

    /// <summary>Rehydrates the session from storage exactly once per circuit.</summary>
    public Task EnsureLoadedAsync() => _restore ??= RestoreAsync();

    private async Task RestoreAsync()
    {
        if (IsLoggedIn)
            return;
        try
        {
            var stored = await _storage.GetAsync<AuthSnapshot>(StorageKey);
            if (stored.Success && stored.Value is not null)
            {
                // A token that is expired (or about to expire) must not be
                // restored: it would render the app for a moment and then
                // bounce to the login page on the first 401 — the flicker bug.
                if (stored.Value.ExpiresAtUtc > DateTime.UtcNow.AddMinutes(1))
                {
                    Token = stored.Value.Token;
                    User = stored.Value.User;
                }
                else
                {
                    await _storage.DeleteAsync(StorageKey);
                }
            }
        }
        catch
        {
            // JS interop unavailable or an old/corrupt snapshot — treated as logged out.
        }
    }

    public async Task SignInAsync(AuthResponse auth)
    {
        Token = auth.AccessToken;
        User = auth.User;
        _restore = Task.CompletedTask; // session is now known; skip any storage read
        await _storage.SetAsync(StorageKey, new AuthSnapshot(auth.AccessToken, auth.User, auth.ExpiresAtUtc));
        Changed?.Invoke();
    }

    public async Task SignOutAsync()
    {
        Token = null;
        User = null;
        await _storage.DeleteAsync(StorageKey);
        Changed?.Invoke();
    }
}
