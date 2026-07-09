using Microsoft.AspNetCore.SignalR;
using Ogdcl.Api.Hubs;
using Ogdcl.Application.Notifications;

namespace Ogdcl.Api.Services;

public class SignalRNotificationChannel : INotificationChannel
{
    private readonly IHubContext<NotificationHub> _hub;

    public SignalRNotificationChannel(IHubContext<NotificationHub> hub)
    {
        _hub = hub;
    }

    public Task PushAsync(int userId, NotificationDto notification, CancellationToken ct = default) =>
        _hub.Clients.User(userId.ToString()).SendAsync("notification", notification, ct);
}
