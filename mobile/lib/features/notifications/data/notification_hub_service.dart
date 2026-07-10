import 'package:signalr_netcore/signalr_client.dart';

import '../../../core/config/env.dart';
import '../../../core/storage/token_storage.dart';
import '../../../domain/app_notification.dart';

abstract class NotificationHubService {
  Future<void> start(void Function(AppNotification) onNotification);
  Future<void> stop();
}

/// Wraps the realtime connection to `/hubs/notifications`. The backend
/// pushes a `notification` event with the same shape as an item from
/// `GET /api/notifications` (see `SignalRNotificationChannel` server-side).
///
/// This channel is best-effort: if it can't connect (offline, server
/// restarted, corporate network blocking websockets) the app still works —
/// notifications just require a manual pull-to-refresh instead of arriving
/// live.
class SignalRNotificationHubService implements NotificationHubService {
  SignalRNotificationHubService(this._tokenStorage);

  final TokenStorage _tokenStorage;
  HubConnection? _connection;

  @override
  Future<void> start(void Function(AppNotification) onNotification) async {
    await stop();

    final connection = HubConnectionBuilder()
        .withUrl(
          Env.notificationHubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => await _tokenStorage.readAccessToken() ?? '',
          ),
        )
        .withAutomaticReconnect()
        .build();

    connection.on('notification', (arguments) {
      if (arguments == null || arguments.isEmpty) return;
      final payload = arguments.first;
      if (payload is Map) {
        onNotification(AppNotification.fromJson(Map<String, dynamic>.from(payload)));
      }
    });

    _connection = connection;
    try {
      await connection.start();
    } catch (_) {
      // Realtime push is a nice-to-have — swallow and let manual refresh cover it.
    }
  }

  @override
  Future<void> stop() async {
    final connection = _connection;
    _connection = null;
    if (connection != null) {
      try {
        await connection.stop();
      } catch (_) {
        // ignore
      }
    }
  }
}
