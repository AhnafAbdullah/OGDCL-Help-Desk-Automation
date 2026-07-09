using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Ogdcl.Application.Notifications;

namespace Ogdcl.Api.Controllers;

[Route("api/notifications")]
[Authorize]
public class NotificationsController : BaseApiController
{
    private readonly NotificationService _notifications;

    public NotificationsController(NotificationService notifications)
    {
        _notifications = notifications;
    }

    [HttpGet]
    public async Task<List<NotificationDto>> Get([FromQuery] bool unreadOnly = false, CancellationToken ct = default) =>
        await _notifications.GetForUserAsync(UserId, unreadOnly, ct);

    [HttpPost("{id:int}/read")]
    public async Task<IActionResult> MarkRead(int id, CancellationToken ct)
    {
        await _notifications.MarkReadAsync(UserId, id, ct);
        return NoContent();
    }
}
