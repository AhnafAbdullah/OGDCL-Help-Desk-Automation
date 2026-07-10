import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../domain/app_notification.dart';
import '../../../shared/widgets/empty_view.dart';
import 'notifications_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(notificationsControllerProvider.notifier).refresh(),
        child: state.items.isEmpty && !state.isLoading
            ? ListView(
                children: const [
                  SizedBox(height: 80),
                  EmptyView(message: "You're all caught up.", icon: Icons.notifications_none),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: state.items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) => _NotificationTile(notification: state.items[index]),
              ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    return ListTile(
      onTap: () => ref.read(notificationsControllerProvider.notifier).markRead(notification.id),
      leading: CircleAvatar(
        backgroundColor: notification.isRead ? Colors.black12 : primary.withValues(alpha: 0.12),
        child: Icon(
          notification.type.icon,
          color: notification.isRead ? Colors.black45 : primary,
          size: 20,
        ),
      ),
      title: Text(
        notification.title,
        style: TextStyle(fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700),
      ),
      subtitle: Text(notification.body),
      trailing: Text(
        Formatters.relative(notification.createdAt),
        style: const TextStyle(fontSize: 11, color: Colors.black45),
      ),
    );
  }
}
