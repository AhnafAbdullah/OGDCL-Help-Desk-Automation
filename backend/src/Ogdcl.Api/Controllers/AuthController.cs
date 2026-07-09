using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Ogdcl.Application.Auth;

namespace Ogdcl.Api.Controllers;

[Route("api/auth")]
public class AuthController : BaseApiController
{
    private readonly AuthService _auth;

    public AuthController(AuthService auth)
    {
        _auth = auth;
    }

    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<AuthResponse> Login(LoginRequest request, CancellationToken ct) =>
        await _auth.LoginAsync(request, ct);

    [HttpPost("refresh")]
    [AllowAnonymous]
    public async Task<AuthResponse> Refresh(RefreshRequest request, CancellationToken ct) =>
        await _auth.RefreshAsync(request, ct);

    [HttpPost("logout")]
    [Authorize]
    public async Task<IActionResult> Logout(RefreshRequest request, CancellationToken ct)
    {
        await _auth.LogoutAsync(request, ct);
        return NoContent();
    }

    [HttpGet("me")]
    [Authorize]
    public async Task<UserDto> Me(CancellationToken ct) =>
        await _auth.GetProfileAsync(UserId, ct);
}
