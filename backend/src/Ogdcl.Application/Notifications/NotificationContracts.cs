using Ogdcl.Domain;

namespace Ogdcl.Application.Notifications;

public record NotificationDto(int Id, NotificationType Type, string Title, string Body, DateTime CreatedAt, DateTime? ReadAt);

/// <summary>
/// Real-time delivery channel. SignalR (in-app) is the guaranteed channel on
/// OGDCL's intranet; an FCM implementation can be layered on later where
/// outbound internet is permitted. Delivery failures must not break the
/// business operation that triggered the notification.
/// </summary>
public interface INotificationChannel
{
    Task PushAsync(int userId, NotificationDto notification, CancellationToken ct = default);
}

public interface INotifier
{
    Task NotifyUsersAsync(IEnumerable<int> userIds, NotificationType type, string title, string body, CancellationToken ct = default);
    Task NotifyRoleAsync(UserRole role, NotificationType type, string title, string body, CancellationToken ct = default);
}
