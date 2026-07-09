using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace Ogdcl.Api.Hubs;

/// <summary>
/// In-app real-time notifications — the guaranteed delivery channel on OGDCL's
/// intranet. Clients connect with their JWT (access_token query parameter) and
/// receive "notification" events addressed to their user id.
/// </summary>
[Authorize]
public class NotificationHub : Hub
{
}
