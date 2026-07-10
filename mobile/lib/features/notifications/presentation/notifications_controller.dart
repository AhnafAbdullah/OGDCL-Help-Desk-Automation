import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/providers.dart';
import '../../../domain/app_notification.dart';
import '../../../mock/mock_notification_repository.dart';
import '../../../mock/noop_notification_hub_service.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_state.dart';
import '../data/notification_api.dart';
import '../data/notification_hub_service.dart';
import '../data/notification_repository.dart';

final notificationApiProvider =
    Provider<NotificationApi>((ref) => NotificationApi(ref.watch(apiClientProvider).dio));

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  if (Env.useMockBackend) return MockNotificationRepository();
  return ApiNotificationRepository(ref.watch(notificationApiProvider), ref.watch(apiClientProvider));
});

final notificationHubServiceProvider = Provider<NotificationHubService>((ref) {
  if (Env.useMockBackend) return NoopNotificationHubService();
  return SignalRNotificationHubService(ref.watch(tokenStorageProvider));
});

class NotificationsState {
  const NotificationsState({this.items = const [], this.isLoading = false, this.error});

  final List<AppNotification> items;
  final bool isLoading;
  final String? error;

  int get unreadCount => items.where((n) => !n.isRead).length;

  NotificationsState copyWith({List<AppNotification>? items, bool? isLoading, String? error}) =>
      NotificationsState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

final notificationsControllerProvider =
    StateNotifierProvider<NotificationsController, NotificationsState>((ref) {
  final controller = NotificationsController(
    ref.watch(notificationRepositoryProvider),
    ref.watch(notificationHubServiceProvider),
  );

  // The auth bootstrap usually resolves before anything watches this
  // provider, so fireImmediately catches an already-authenticated session.
  ref.listen<AuthState>(authControllerProvider, (previous, next) {
    if (next is AuthAuthenticated) {
      controller.onSignedIn();
    } else if (next is AuthUnauthenticated) {
      controller.onSignedOut();
    }
  }, fireImmediately: true);

  return controller;
});

class NotificationsController extends StateNotifier<NotificationsState> {
  NotificationsController(this._repository, this._hub) : super(const NotificationsState());

  final NotificationRepository _repository;
  final NotificationHubService _hub;

  Future<void> onSignedIn() async {
    await refresh();
    await _hub.start(_handleLiveNotification);
  }

  Future<void> onSignedOut() async {
    await _hub.stop();
    state = const NotificationsState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _repository.list();
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _handleLiveNotification(AppNotification notification) {
    final alreadyKnown = state.items.any((n) => n.id == notification.id);
    if (alreadyKnown) return;
    state = state.copyWith(items: [notification, ...state.items]);
  }

  Future<void> markRead(int id) async {
    final index = state.items.indexWhere((n) => n.id == id);
    if (index == -1 || state.items[index].isRead) return;

    final updated = [...state.items];
    updated[index] = updated[index].markRead(DateTime.now());
    state = state.copyWith(items: updated);

    try {
      await _repository.markRead(id);
    } catch (_) {
      // Optimistic update — a manual refresh reconciles if this failed.
    }
  }

  @override
  void dispose() {
    _hub.stop();
    super.dispose();
  }
}
