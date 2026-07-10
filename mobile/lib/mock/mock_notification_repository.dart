import '../core/network/api_exception.dart';
import '../domain/app_notification.dart';
import '../domain/user.dart';
import '../features/notifications/data/notification_repository.dart';
import 'mock_database.dart';

class MockNotificationRepository implements NotificationRepository {
  final _db = MockDatabase.instance;

  User get _actor {
    final user = _db.currentUser;
    if (user == null) throw ApiException('Not signed in.', statusCode: 401);
    return user;
  }

  @override
  Future<List<AppNotification>> list({bool unreadOnly = false}) async {
    final all = _db.notificationsFor(_actor.id);
    return unreadOnly ? all.where((n) => !n.isRead).toList() : all;
  }

  @override
  Future<void> markRead(int id) async {
    _db.markNotificationRead(_actor.id, id);
  }
}
