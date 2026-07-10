import '../../../core/network/api_client.dart';
import '../../../domain/app_notification.dart';
import 'notification_api.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> list({bool unreadOnly = false});
  Future<void> markRead(int id);
}

class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository(this._api, this._apiClient);

  final NotificationApi _api;
  final ApiClient _apiClient;

  @override
  Future<List<AppNotification>> list({bool unreadOnly = false}) => _apiClient.guarded(() async {
        final res = await _api.list(unreadOnly: unreadOnly);
        return (res.data as List)
            .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<void> markRead(int id) => _apiClient.guarded(() => _api.markRead(id));
}
