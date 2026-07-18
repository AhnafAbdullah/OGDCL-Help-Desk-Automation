import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/routing/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/complaint.dart';
import '../../../domain/enums.dart';
import '../../../domain/user.dart';
import '../../../domain/visitor.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_state.dart';
import '../../complaints/presentation/complaints_providers.dart';
import '../../complaints/presentation/widgets/complaint_card.dart';
import '../../parking/presentation/parking_providers.dart';
import '../../visitors/presentation/visitors_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    if (authState is! AuthAuthenticated) return const LoadingView();
    final user = authState.user;

    // No Scaffold/AppBar here — the surrounding AppShell provides those.
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myComplaintsProvider);
          ref.invalidate(assignedComplaintsProvider);
          ref.invalidate(parkingOverviewProvider);
          ref.invalidate(myVisitorsProvider);
          ref.invalidate(gateVisitsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
          children: [
              _greeting(context, user),
              const SizedBox(height: 20),
              Text(
                'Help Desk',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              switch (user.role) {
                UserRole.handler => const _HandlerStats(),
                UserRole.employee || UserRole.security || UserRole.admin => const _EmployeeStats(),
              },
              const SizedBox(height: 24),
              Text(
                'Smart Parking',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const _ParkingStatCard(),
              const SizedBox(height: 24),
              Text(
                'Visitors',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _VisitorStatCard(isSecurity: user.role == UserRole.security),
              const SizedBox(height: 24),
              Text(
                'Recent Complaints',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              switch (user.role) {
                UserRole.handler => const _RecentAssignedComplaints(),
                UserRole.admin || UserRole.employee || UserRole.security => const _RecentMyComplaints(),
              },
            ],
          ),
        ),
      );
  }

  Widget _greeting(BuildContext context, User user) {
    final designation = user.designation ?? user.role.label;
    final subtitle = user.department != null ? '$designation • ${user.department}' : designation;
    return Row(
      children: [
        UserAvatar(name: user.displayName, radius: 26, backgroundColor: AppColors.tint(AppColors.brand)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Welcome back,', style: TextStyle(color: Colors.black54, fontSize: 13)),
              Text(
                user.displayName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

}

/// Live free-slot count from the (mock) sensor feed — tapping opens the
/// Smart Parking tab.
class _ParkingStatCard extends ConsumerWidget {
  const _ParkingStatCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(parkingOverviewProvider);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go(RoutePaths.parking),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: overviewAsync.when(
            data: (o) => Row(
              children: [
                const Icon(Icons.local_parking_outlined, color: AppColors.accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${o.free} of ${o.total} slots free',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      Text(
                        o.flagged > 0
                            ? '${o.flagged} slot${o.flagged == 1 ? '' : 's'} flagged — unregistered vehicle'
                            : 'All parked vehicles are registered',
                        style: TextStyle(
                          color: o.flagged > 0 ? AppColors.bad : Colors.black45,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.black26),
              ],
            ),
            loading: () => const SizedBox(
              height: 36,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, _) => const Text(
              'Parking data unavailable.',
              style: TextStyle(color: Colors.black45, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}

/// Visitor headline for the dashboard: the guard sees today's gate queue,
/// everyone else sees their own registered guests.
class _VisitorStatCard extends ConsumerWidget {
  const _VisitorStatCard({required this.isSecurity});

  final bool isSecurity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(isSecurity ? gateVisitsProvider : myVisitorsProvider);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go(RoutePaths.visitors),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: visitsAsync.when(
            data: (visits) {
              final pending = visits.where((v) => v.status == VisitStatus.preRegistered).length;
              final onSite = visits.where((v) => v.status == VisitStatus.checkedIn).length;
              final headline = isSecurity
                  ? '$pending expected • $onSite on site'
                  : (pending + onSite == 0
                      ? 'No active visitors'
                      : '$pending expected • $onSite on site');
              final sub = isSecurity
                  ? 'Verify visitor codes at the gate desk'
                  : 'Register a guest before they arrive';
              return Row(
                children: [
                  const Icon(Icons.badge_outlined, color: AppColors.accent),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headline,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        Text(sub, style: const TextStyle(color: Colors.black45, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.black26),
                ],
              );
            },
            loading: () => const SizedBox(
              height: 36,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, _) => const Text(
              'Visitor data unavailable.',
              style: TextStyle(color: Colors.black45, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmployeeStats extends ConsumerWidget {
  const _EmployeeStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complaintsAsync = ref.watch(myComplaintsProvider);
    return complaintsAsync.when(
      data: (complaints) {
        final active = complaints
            .where((c) =>
                c.status == ComplaintStatus.open ||
                c.status == ComplaintStatus.assigned ||
                c.status == ComplaintStatus.inProgress ||
                c.status == ComplaintStatus.pendingApproval)
            .length;
        final resolved = complaints.where((c) => c.status == ComplaintStatus.resolved).length;
        final closed = complaints.where((c) => c.status == ComplaintStatus.closed).length;
        return Row(
          children: [
            Expanded(child: _StatTile(label: 'Active', value: active, color: AppColors.accent)),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(label: 'Resolved', value: resolved, color: AppColors.ok)),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(label: 'Closed', value: closed, color: AppColors.neutral)),
          ],
        );
      },
      loading: () => const _StatsLoading(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _HandlerStats extends ConsumerWidget {
  const _HandlerStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complaintsAsync = ref.watch(assignedComplaintsProvider);
    return complaintsAsync.when(
      data: (complaints) {
        final assigned = complaints.where((c) => c.status == ComplaintStatus.assigned).length;
        final inProgress = complaints.where((c) => c.status == ComplaintStatus.inProgress).length;
        final resolved = complaints.where((c) => c.status == ComplaintStatus.resolved).length;
        final overdue = complaints.where((c) => c.isOverdue).length;
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _StatTile(label: 'Assigned', value: assigned, color: AppColors.warn)),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(label: 'In Progress', value: inProgress, color: AppColors.accent),
                ),
                const SizedBox(width: 10),
                Expanded(child: _StatTile(label: 'Resolved', value: resolved, color: AppColors.ok)),
              ],
            ),
            if (overdue > 0) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.tint(AppColors.bad),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.bad, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '$overdue complaint${overdue == 1 ? '' : 's'} overdue',
                      style: const TextStyle(color: AppColors.bad, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
      loading: () => const _StatsLoading(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.tint(color), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.85), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StatsLoading extends StatelessWidget {
  const _StatsLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 88, child: Center(child: CircularProgressIndicator()));
  }
}

class _RecentMyComplaints extends ConsumerWidget {
  const _RecentMyComplaints();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complaintsAsync = ref.watch(myComplaintsProvider);
    return complaintsAsync.when(
      data: (complaints) => _RecentList(
        complaints: complaints,
        emptyMessage: "You haven't submitted any complaints yet.",
      ),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) =>
          ErrorView(message: error is ApiException ? error.message : 'Failed to load complaints.'),
    );
  }
}

class _RecentAssignedComplaints extends ConsumerWidget {
  const _RecentAssignedComplaints();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complaintsAsync = ref.watch(assignedComplaintsProvider);
    return complaintsAsync.when(
      data: (complaints) => _RecentList(
        complaints: complaints,
        emptyMessage: 'No open complaints are assigned to you.',
      ),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) =>
          ErrorView(message: error is ApiException ? error.message : 'Failed to load complaints.'),
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({required this.complaints, required this.emptyMessage});

  final List<ComplaintSummary> complaints;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final recent = complaints.take(5).toList();
    if (recent.isEmpty) {
      return EmptyView(message: emptyMessage, icon: Icons.confirmation_number_outlined);
    }
    return Column(
      children: [
        for (final c in recent)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: ComplaintCard(complaint: c)),
      ],
    );
  }
}
