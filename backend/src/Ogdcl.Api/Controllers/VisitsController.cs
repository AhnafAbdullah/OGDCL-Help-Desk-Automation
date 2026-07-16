using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Ogdcl.Application.Visits;

namespace Ogdcl.Api.Controllers;

[Route("api/visits")]
[Authorize]
public class VisitsController : BaseApiController
{
    private readonly VisitService _visits;

    public VisitsController(VisitService visits)
    {
        _visits = visits;
    }

    [HttpPost]
    public async Task<VisitDto> Register(RegisterVisitRequest request, CancellationToken ct) =>
        await _visits.RegisterAsync(UserId, request, ct);

    [HttpGet("mine")]
    public async Task<List<VisitDto>> Mine(CancellationToken ct) =>
        await _visits.GetMineAsync(UserId, ct);

    [HttpGet("pending")]
    [Authorize(Roles = "Security,SuperAdmin")]
    public async Task<List<VisitDto>> Pending(CancellationToken ct) =>
        await _visits.GetPendingAsync(ct);

    [HttpGet("active")]
    [Authorize(Roles = "Security,SuperAdmin")]
    public async Task<List<VisitDto>> Active(CancellationToken ct) =>
        await _visits.GetActiveAsync(ct);

    [HttpGet("{id:int}")]
    public async Task<VisitDto> Get(int id, CancellationToken ct) =>
        await _visits.GetByIdAsync(id, UserId, ct);

    [HttpPost("{id:int}/verify-otp")]
    [Authorize(Roles = "Security,SuperAdmin")]
    public async Task<VisitDto> VerifyOtp(int id, VerifyOtpRequest request, CancellationToken ct) =>
        await _visits.VerifyOtpAsync(id, UserId, request, ct);

    [HttpPost("{id:int}/resend-otp")]
    public async Task<VisitDto> ResendOtp(int id, CancellationToken ct) =>
        await _visits.ResendOtpAsync(id, UserId, ct);

    [HttpPost("{id:int}/issue-card")]
    [Authorize(Roles = "Security,SuperAdmin")]
    public async Task<VisitDto> IssueCard(int id, IssueCardRequest request, CancellationToken ct) =>
        await _visits.IssueCardAsync(id, UserId, request, ct);

    [HttpPost("{id:int}/close")]
    [Authorize(Roles = "Security,SuperAdmin")]
    public async Task<VisitDto> Close(int id, CancellationToken ct) =>
        await _visits.CloseAsync(id, UserId, ct);

    [HttpPost("{id:int}/cancel")]
    public async Task<VisitDto> Cancel(int id, CancellationToken ct) =>
        await _visits.CancelAsync(id, UserId, ct);
}
