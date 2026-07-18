import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_state.dart';
import '../../complaints/presentation/new_complaint_form.dart';
import '../../notifications/presentation/notifications_controller.dart';

/// Persistent chrome (app bar, bottom nav, drawer, New Complaint button)
/// around the app's five tabs. Complaint detail / coming-soon screens
/// push full-screen on top of this instead of nesting inside it.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _tabPaths = [
    RoutePaths.home,
    RoutePaths.complaints,
    RoutePaths.parking,
    RoutePaths.visitors,
    RoutePaths.notifications,
  ];
  static const _titles = ['Dashboard', 'Complaints', 'Smart Parking', 'Visitors', 'Notifications'];

  /// Tabs where the circular New Complaint button makes sense.
  static const _fabTabs = {0, 1};

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
          if (selectedIndex != _tabPaths.length - 1)
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
      floatingActionButton: _fabTabs.contains(selectedIndex)
          ? FloatingActionButton(
              onPressed: () => showNewComplaintSheet(context),
              shape: const CircleBorder(),
              tooltip: 'New Complaint',
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => context.go(_tabPaths[index]),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Complaints',
          ),
          const NavigationDestination(
            icon: Icon(Icons.local_parking_outlined),
            selectedIcon: Icon(Icons.local_parking),
            label: 'Parking',
          ),
          const NavigationDestination(
            icon: Icon(Icons.badge_outlined),
            selectedIcon: Icon(Icons.badge),
            label: 'Visitors',
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
                  UserAvatar(name: user?.displayName ?? '', radius: 26),
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
                          user == null ? '' : (user.designation ?? user.role.label),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (user?.department != null)
                          Text(
                            user!.department!,
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
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
                    leading: const Icon(Icons.local_parking_outlined),
                    title: const Text('Smart Parking'),
                    onTap: () => _goTab(context, RoutePaths.parking),
                  ),
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('Visitors'),
                    onTap: () => _goTab(context, RoutePaths.visitors),
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
    // Capture the router before popping the drawer — after the pop this
    // drawer's context is being disposed and can't resolve GoRouter.
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(RoutePaths.comingSoon(module));
  }

  void _goTab(BuildContext context, String path) {
    // Same capture-before-pop rule as _openComingSoon.
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(path);
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    // Capture the auth controller and navigator BEFORE popping the drawer.
    // The pop disposes this _AppDrawer (and its `ref`/`context`), so reading
    // the provider through `ref` after the dialog closes would hit a defunct
    // ref and silently do nothing — which is exactly what made logout appear
    // to "do nothing". The controller object itself outlives the widget.
    final authController = ref.read(authControllerProvider.notifier);
    final navigator = Navigator.of(context);
    navigator.pop(); // close the drawer
    final confirmed = await showDialog<bool>(
      context: navigator.context,
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
      await authController.logout();
    }
  }
}
