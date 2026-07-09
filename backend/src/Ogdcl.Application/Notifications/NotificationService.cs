using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Ogdcl.Application.Common;
using Ogdcl.Domain;
using Ogdcl.Domain.Entities;

namespace Ogdcl.Application.Notifications;

public class NotificationService : INotifier
{
    private readonly IAppDbContext _db;
    private readonly INotificationChannel _channel;
    private readonly ILogger<NotificationService> _logger;

    public NotificationService(IAppDbContext db, INotificationChannel channel, ILogger<NotificationService> logger)
    {
        _db = db;
        _channel = channel;
        _logger = logger;
    }

    public async Task NotifyUsersAsync(IEnumerable<int> userIds, NotificationType type, string title, string body, CancellationToken ct = default)
    {
        var notifications = userIds.Distinct().Select(userId => new Notification
        {
            UserId = userId,
            Type = type,
            Title = title,
            Body = body,
        }).ToList();

        if (notifications.Count == 0)
            return;

        _db.Notifications.AddRange(notifications);
        await _db.SaveChangesAsync(ct);

        foreach (var n in notifications)
        {
            try
            {
                await _channel.PushAsync(n.UserId,
                    new NotificationDto(n.Id, n.Type, n.Title, n.Body, n.CreatedAt, n.ReadAt), ct);
            }
            catch (Exception ex)
            {
                // The notification row is already persisted; a push failure only
                // means the user sees it on next poll instead of instantly.
                _logger.LogWarning(ex, "Real-time push failed for user {UserId}", n.UserId);
            }
        }
    }

    public async Task NotifyRoleAsync(UserRole role, NotificationType type, string title, string body, CancellationToken ct = default)
    {
        var userIds = await _db.Users
            .Where(u => u.Role == role && u.IsActive)
            .Select(u => u.Id)
            .ToListAsync(ct);
        await NotifyUsersAsync(userIds, type, title, body, ct);
    }

    public async Task<List<NotificationDto>> GetForUserAsync(int userId, bool unreadOnly, CancellationToken ct = default)
    {
        var query = _db.Notifications.Where(n => n.UserId == userId);
        if (unreadOnly)
            query = query.Where(n => n.ReadAt == null);

        return await query
            .OrderByDescending(n => n.CreatedAt)
            .Take(100)
            .Select(n => new NotificationDto(n.Id, n.Type, n.Title, n.Body, n.CreatedAt, n.ReadAt))
            .ToListAsync(ct);
    }

    public async Task MarkReadAsync(int userId, int notificationId, CancellationToken ct = default)
    {
        var notification = await _db.Notifications
            .FirstOrDefaultAsync(n => n.Id == notificationId && n.UserId == userId, ct)
            ?? throw new NotFoundException("Notification not found.");

        notification.ReadAt ??= DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);
    }
}
