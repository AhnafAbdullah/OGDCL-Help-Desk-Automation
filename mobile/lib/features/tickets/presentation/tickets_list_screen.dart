import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/routing/route_paths.dart';
import '../../../domain/enums.dart';
import '../../../domain/ticket.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_state.dart';
import 'tickets_providers.dart';
import 'widgets/ticket_card.dart';

class TicketsListScreen extends ConsumerStatefulWidget {
  const TicketsListScreen({super.key});

  @override
  ConsumerState<TicketsListScreen> createState() => _TicketsListScreenState();
}

class _TicketsListScreenState extends ConsumerState<TicketsListScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  List<String> _tabsForRole(UserRole role) => switch (role) {
        UserRole.handler => const ['Assigned to Me', 'My Tickets'],
        UserRole.admin => const ['All Tickets', 'My Tickets'],
        UserRole.employee || UserRole.security => const ['My Tickets'],
      };

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    if (authState is! AuthAuthenticated) return const Scaffold(body: LoadingView());

    final tabs = _tabsForRole(authState.user.role);
    if (_tabController == null || _tabController!.length != tabs.length) {
      _tabController?.dispose();
      _tabController = TabController(length: tabs.length, vsync: this);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tickets'),
        bottom: tabs.length > 1
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [for (final t in tabs) Tab(text: t)],
              )
            : null,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final t in tabs)
            switch (t) {
              'Assigned to Me' => const _AssignedTicketsTab(),
              'All Tickets' => const _AllTicketsTab(),
              _ => const _MyTicketsTab(),
            },
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RoutePaths.newTicket),
        icon: const Icon(Icons.add),
        label: const Text('New Complaint'),
      ),
    );
  }
}

class _MyTicketsTab extends ConsumerWidget {
  const _MyTicketsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(myTicketsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(myTicketsProvider.future),
      child: ticketsAsync.when(
        data: (tickets) => _TicketList(
          tickets: tickets,
          emptyMessage: "You haven't submitted any complaints yet.",
        ),
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error is ApiException ? error.message : 'Failed to load tickets.',
          onRetry: () => ref.invalidate(myTicketsProvider),
        ),
      ),
    );
  }
}

class _AssignedTicketsTab extends ConsumerWidget {
  const _AssignedTicketsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(assignedTicketsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(assignedTicketsProvider.future),
      child: ticketsAsync.when(
        data: (tickets) => _TicketList(
          tickets: tickets,
          emptyMessage: 'No open tickets are assigned to you.',
        ),
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error is ApiException ? error.message : 'Failed to load tickets.',
          onRetry: () => ref.invalidate(assignedTicketsProvider),
        ),
      ),
    );
  }
}

class _AllTicketsTab extends ConsumerStatefulWidget {
  const _AllTicketsTab();

  @override
  ConsumerState<_AllTicketsTab> createState() => _AllTicketsTabState();
}

class _AllTicketsTabState extends ConsumerState<_AllTicketsTab> {
  TicketStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final filter = AdminTicketFilter(status: _statusFilter, pageSize: 50);
    final ticketsAsync = ref.watch(adminTicketsProvider(filter));

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('All'),
                  selected: _statusFilter == null,
                  onSelected: (_) => setState(() => _statusFilter = null),
                ),
              ),
              for (final status in TicketStatus.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(status.label),
                    selected: _statusFilter == status,
                    onSelected: (_) => setState(() => _statusFilter = status),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(adminTicketsProvider(filter).future),
            child: ticketsAsync.when(
              data: (result) => _TicketList(
                tickets: result.items,
                emptyMessage: 'No tickets match this filter.',
              ),
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                message: error is ApiException ? error.message : 'Failed to load tickets.',
                onRetry: () => ref.invalidate(adminTicketsProvider(filter)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TicketList extends StatelessWidget {
  const _TicketList({required this.tickets, required this.emptyMessage});

  final List<TicketSummary> tickets;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          EmptyView(message: emptyMessage, icon: Icons.confirmation_number_outlined),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: tickets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => TicketCard(ticket: tickets[index]),
    );
  }
}
