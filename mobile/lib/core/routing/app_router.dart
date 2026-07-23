import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/coming_soon/presentation/coming_soon_screen.dart';
import '../../features/complaints/presentation/complaint_detail_screen.dart';
import '../../features/complaints/presentation/complaints_list_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import 'route_paths.dart';

const _comingSoonModules = <String, (String, IconData)>{
  'visitors': ('Visitors', Icons.badge_outlined),
  'gate-desk': ('Gate Desk', Icons.shield_outlined),
  'smart-parking': ('Smart Parking', Icons.local_parking_outlined),
  'settings': ('Settings', Icons.settings_outlined),
};

/// Bridges [authControllerProvider] into go_router's `refreshListenable` so
/// the router re-evaluates `redirect` whenever auth state changes (sign in,
/// sign out, or a session-expiry forced logout).
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authControllerProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authControllerProvider);
    final location = state.matchedLocation;
    final isLoggingIn = location == RoutePaths.login;
    final isSplash = location == RoutePaths.splash;

    if (authState is AuthInitial || authState is AuthLoading) {
      return isSplash ? null : RoutePaths.splash;
    }

    if (authState is AuthUnauthenticated) {
      return isLoggingIn ? null : RoutePaths.login;
    }

    // AuthAuthenticated
    if (isLoggingIn || isSplash) return RoutePaths.home;
    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Not Found')),
      body: Center(child: Text('No route for ${state.uri}')),
    ),
    routes: [
      GoRoute(path: RoutePaths.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: RoutePaths.login, builder: (context, state) => const LoginScreen()),
      // New Complaint opens as a modal popup (see NewComplaintForm), not a route.
      GoRoute(
        path: '/complaints/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return ComplaintDetailScreen(complaintId: id);
        },
      ),
      GoRoute(
        path: '/coming-soon/:module',
        builder: (context, state) {
          final module = state.pathParameters['module'] ?? '';
          final entry = _comingSoonModules[module];
          return ComingSoonScreen(
            title: entry?.$1 ?? 'Coming Soon',
            icon: entry?.$2 ?? Icons.construction_outlined,
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: RoutePaths.home, builder: (context, state) => const DashboardScreen()),
          GoRoute(
            path: RoutePaths.complaints,
            builder: (context, state) => const ComplaintsListScreen(),
          ),
          GoRoute(
            path: RoutePaths.notifications,
            builder: (context, state) => const NotificationsScreen(),
          ),
        ],
      ),
    ],
  );
});
