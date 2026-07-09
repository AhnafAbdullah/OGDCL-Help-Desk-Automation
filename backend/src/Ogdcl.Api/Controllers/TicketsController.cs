using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Ogdcl.Application.Tickets;

namespace Ogdcl.Api.Controllers;

[Route("api/tickets")]
[Authorize]
public class TicketsController : BaseApiController
{
    private const long MaxAttachmentBytes = 10 * 1024 * 1024;

    private readonly TicketService _tickets;

    public TicketsController(TicketService tickets)
    {
        _tickets = tickets;
    }

    [HttpPost]
    public async Task<TicketDto> Create(CreateTicketRequest request, CancellationToken ct) =>
        await _tickets.CreateAsync(UserId, request, ct);

    [HttpGet("mine")]
    public async Task<List<TicketSummaryDto>> Mine(CancellationToken ct) =>
        await _tickets.GetMineAsync(UserId, ct);

    [HttpGet("assigned")]
    [Authorize(Roles = "Handler,Admin")]
    public async Task<List<TicketSummaryDto>> Assigned(CancellationToken ct) =>
        await _tickets.GetAssignedAsync(UserId, ct);

    [HttpGet("{id:int}")]
    public async Task<TicketDto> Get(int id, CancellationToken ct) =>
        await _tickets.GetByIdAsync(id, UserId, ct);

    [HttpPatch("{id:int}/status")]
    public async Task<TicketDto> UpdateStatus(int id, UpdateTicketStatusRequest request, CancellationToken ct) =>
        await _tickets.UpdateStatusAsync(id, UserId, request, ct);

    [HttpPatch("{id:int}/assign")]
    [Authorize(Roles = "Admin")]
    public async Task<TicketDto> Assign(int id, AssignTicketRequest request, CancellationToken ct) =>
        await _tickets.AssignAsync(id, UserId, request, ct);

    [HttpPost("{id:int}/feedback")]
    public async Task<TicketDto> Feedback(int id, TicketFeedbackRequest request, CancellationToken ct) =>
        await _tickets.AddFeedbackAsync(id, UserId, request, ct);

    [HttpPost("{id:int}/attachments")]
    [RequestSizeLimit(MaxAttachmentBytes)]
    public async Task<AttachmentDto> Upload(int id, IFormFile file, CancellationToken ct)
    {
        if (file is null || file.Length == 0)
            throw new Ogdcl.Application.Common.AppValidationException("A non-empty file is required.");
        if (file.Length > MaxAttachmentBytes)
            throw new Ogdcl.Application.Common.AppValidationException("Attachments are limited to 10 MB.");

        await using var stream = file.OpenReadStream();
        return await _tickets.AddAttachmentAsync(id, UserId, file.FileName,
            file.ContentType ?? "application/octet-stream", file.Length, stream, ct);
    }

    [HttpGet("{id:int}/attachments/{attachmentId:int}")]
    public async Task<IActionResult> Download(int id, int attachmentId, CancellationToken ct)
    {
        var (meta, content) = await _tickets.GetAttachmentAsync(id, attachmentId, UserId, ct);
        return File(content, meta.ContentType, meta.FileName);
    }
}
