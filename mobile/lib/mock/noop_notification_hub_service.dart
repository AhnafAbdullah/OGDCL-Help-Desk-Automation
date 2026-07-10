import '../domain/app_notification.dart';
import '../features/notifications/data/notification_hub_service.dart';

/// Used in demo mode: there's no real server to open a realtime connection
/// to, so notifications only ever update via the mutations made in-app
/// (which the mock repositories already record) or a manual refresh.
class NoopNotificationHubService implements NotificationHubService {
  @override
  Future<void> start(void Function(AppNotification) onNotification) async {}

  @override
  Future<void> stop() async {}
}
