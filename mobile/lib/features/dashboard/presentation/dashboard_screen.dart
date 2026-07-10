import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/routing/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/enums.dart';
import '../../../domain/ticket.dart';
import '../../../domain/user.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_state.dart';
import '../../tickets/presentation/tickets_providers.dart';
import '../../tickets/presentation/widgets/ticket_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    if (authState is! AuthAuthenticated) return const Scaffold(body: LoadingView());
    final user = authState.user;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myTicketsProvider);
            ref.invalidate(assignedTicketsProvider);
            ref.invalidate(adminTicketCountsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
            children: [
              _greeting(context, user),
              const SizedBox(height: 20),
              switch (user.role) {
                UserRole.admin => const _AdminStats(),
                UserRole.handler => const _HandlerStats(),
                UserRole.employee || UserRole.security => const _EmployeeStats(),
              },
              const SizedBox(height: 24),
              Text(
                'Recent Tickets',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              switch (user.role) {
                UserRole.handler => const _RecentAssignedTickets(),
                UserRole.admin || UserRole.employee || UserRole.security => const _RecentMyTickets(),
              },
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RoutePaths.newTicket),
        icon: const Icon(Icons.add),
        label: const Text('New Complaint'),
      ),
    );
  }

  Widget _greeting(BuildContext context, User user) {
    final subtitle = user.department != null ? '${user.role.label} • ${user.department}' : user.role.label;
    return Row(
      children: [
        const AppLogo(size: 44),
        const SizedBox(width: 12),
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

class _EmployeeStats extends ConsumerWidget {
  const _EmployeeStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(myTicketsProvider);
    return ticketsAsync.when(
      data: (tickets) {
        final active = tickets
            .where((t) =>
                t.status == TicketStatus.open ||
                t.status == TicketStatus.assigned ||
                t.status == TicketStatus.inProgress)
            .length;
        final resolved = tickets.where((t) => t.status == TicketStatus.resolved).length;
        final closed = tickets.where((t) => t.status == TicketStatus.closed).length;
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
    final ticketsAsync = ref.watch(assignedTicketsProvider);
    return ticketsAsync.when(
      data: (tickets) {
        final assigned = tickets.where((t) => t.status == TicketStatus.assigned).length;
        final inProgress = tickets.where((t) => t.status == TicketStatus.inProgress).length;
        final resolved = tickets.where((t) => t.status == TicketStatus.resolved).length;
        return Row(
          children: [
            Expanded(child: _StatTile(label: 'Assigned', value: assigned, color: AppColors.warn)),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(label: 'In Progress', value: inProgress, color: AppColors.accent)),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(label: 'Resolved', value: resolved, color: AppColors.ok)),
          ],
        );
      },
      loading: () => const _StatsLoading(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _AdminStats extends ConsumerWidget {
  const _AdminStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(adminTicketCountsProvider);
    return countsAsync.when(
      data: (counts) {
        final total = counts[null] ?? 0;
        final open = counts[TicketStatus.open] ?? 0;
        final inProgress =
            (counts[TicketStatus.assigned] ?? 0) + (counts[TicketStatus.inProgress] ?? 0);
        final resolved = counts[TicketStatus.resolved] ?? 0;
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _StatTile(label: 'Total', value: total, color: AppColors.brand)),
                const SizedBox(width: 10),
                Expanded(child: _StatTile(label: 'Open', value: open, color: AppColors.warn)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StatTile(label: 'In Progress', value: inProgress, color: AppColors.accent),
                ),
                const SizedBox(width: 10),
                Expanded(child: _StatTile(label: 'Resolved', value: resolved, color: AppColors.ok)),
              ],
            ),
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

class _RecentMyTickets extends ConsumerWidget {
  const _RecentMyTickets();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(myTicketsProvider);
    return ticketsAsync.when(
      data: (tickets) => _RecentList(
        tickets: tickets,
        emptyMessage: "You haven't submitted any complaints yet.",
      ),
      loading: () =>
          const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator())),
      error: (error, _) =>
          ErrorView(message: error is ApiException ? error.message : 'Failed to load tickets.'),
    );
  }
}

class _RecentAssignedTickets extends ConsumerWidget {
  const _RecentAssignedTickets();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(assignedTicketsProvider);
    return ticketsAsync.when(
      data: (tickets) => _RecentList(
        tickets: tickets,
        emptyMessage: 'No open tickets are assigned to you.',
      ),
      loading: () =>
          const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator())),
      error: (error, _) =>
          ErrorView(message: error is ApiException ? error.message : 'Failed to load tickets.'),
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({required this.tickets, required this.emptyMessage});

  final List<TicketSummary> tickets;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final recent = tickets.take(5).toList();
    if (recent.isEmpty) {
      return EmptyView(message: emptyMessage, icon: Icons.confirmation_number_outlined);
    }
    return Column(
      children: [
        for (final t in recent) Padding(padding: const EdgeInsets.only(bottom: 10), child: TicketCard(ticket: t)),
      ],
    );
  }
}
