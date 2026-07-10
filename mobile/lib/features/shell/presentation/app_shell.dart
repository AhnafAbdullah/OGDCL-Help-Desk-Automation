import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_state.dart';
import '../../notifications/presentation/notifications_controller.dart';

/// Persistent chrome (app bar, bottom nav, drawer) around the three
/// Help-Desk tabs. Reached ticket detail / new-complaint / coming-soon
/// screens push full-screen on top of this instead of nesting inside it.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _tabPaths = [RoutePaths.home, RoutePaths.tickets, RoutePaths.notifications];
  static const _titles = ['Dashboard', 'Tickets', 'Notifications'];

  int _indexForLocation(String location) {
    final index = _tabPaths.indexWhere((path) => location.startsWith(path));
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _indexForLocation(location);
    final authState = ref.watch(authControllerProvider);
    final unreadCount = ref.watch(notificationsControllerProvider.select((s) => s.unreadCount));

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[selectedIndex]),
        actions: [
          if (selectedIndex != 2)
            IconButton(
              onPressed: () => context.go(RoutePaths.notifications),
              icon: Badge(
                isLabelVisible: unreadCount > 0,
                label: Text('$unreadCount'),
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
        ],
      ),
      drawer: _AppDrawer(authState: authState),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => context.go(_tabPaths[index]),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.confirmation_number),
            label: 'Tickets',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: const Icon(Icons.notifications),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }
}

class _AppDrawer extends ConsumerWidget {
  const _AppDrawer({required this.authState});

  final AuthState authState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = authState;
    final user = state is AuthAuthenticated ? state.user : null;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: AppColors.brand,
              child: Row(
                children: [
                  const AppLogo(size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user == null
                              ? ''
                              : (user.department != null
                                  ? '${user.role.label} • ${user.department}'
                                  : user.role.label),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('Visitors'),
                    onTap: () => _openComingSoon(context, 'visitors'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('Gate Desk'),
                    onTap: () => _openComingSoon(context, 'gate-desk'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.local_parking_outlined),
                    title: const Text('Smart Parking'),
                    onTap: () => _openComingSoon(context, 'smart-parking'),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Settings'),
                    onTap: () => _openComingSoon(context, 'settings'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.bad),
              title: const Text('Log Out', style: TextStyle(color: AppColors.bad)),
              onTap: () => _confirmLogout(context, ref),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openComingSoon(BuildContext context, String module) {
    Navigator.of(context).pop();
    context.push(RoutePaths.comingSoon(module));
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    Navigator.of(context).pop();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }
}
