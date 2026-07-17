import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/complaint.dart';
import '../../../domain/enums.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_state.dart';
import 'complaints_providers.dart';
import 'widgets/complaint_card.dart';

class ComplaintsListScreen extends ConsumerStatefulWidget {
  const ComplaintsListScreen({super.key});

  @override
  ConsumerState<ComplaintsListScreen> createState() => _ComplaintsListScreenState();
}

class _ComplaintsListScreenState extends ConsumerState<ComplaintsListScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  List<String> _tabsForRole(UserRole role) => switch (role) {
        UserRole.handler => const ['Available', 'Assigned to Me', 'My Complaints'],
        UserRole.employee || UserRole.security || UserRole.admin => const ['My Complaints'],
      };

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No Scaffold/AppBar here — the surrounding AppShell provides those.
    // Returning a bare body avoids the nested-Scaffold double app bar.
    final authState = ref.watch(authControllerProvider);
    if (authState is! AuthAuthenticated) return const LoadingView();

    final tabs = _tabsForRole(authState.user.role);
    if (_tabController == null || _tabController!.length != tabs.length) {
      _tabController?.dispose();
      _tabController = TabController(length: tabs.length, vsync: this);
    }

    Widget tabViewFor(String t) => switch (t) {
          'Available' => const _AvailableComplaintsTab(),
          'Assigned to Me' => const _AssignedComplaintsTab(),
          _ => const _MyComplaintsTab(),
        };

    // Single-tab roles (Employee) don't need a TabBar at all.
    if (tabs.length == 1) return tabViewFor(tabs.first);

    return Column(
      children: [
        Material(
          color: Colors.white,
          elevation: 1,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.brand,
            unselectedLabelColor: Colors.black54,
            indicatorColor: AppColors.brand,
            tabs: [for (final t in tabs) Tab(text: t)],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [for (final t in tabs) tabViewFor(t)],
          ),
        ),
      ],
    );
  }
}

class _MyComplaintsTab extends ConsumerWidget {
  const _MyComplaintsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complaintsAsync = ref.watch(myComplaintsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(myComplaintsProvider.future),
      child: complaintsAsync.when(
        data: (complaints) => _ComplaintList(
          complaints: complaints,
          emptyMessage: "You haven't submitted any complaints yet.",
        ),
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error is ApiException ? error.message : 'Failed to load complaints.',
          onRetry: () => ref.invalidate(myComplaintsProvider),
        ),
      ),
    );
  }
}

class _AssignedComplaintsTab extends ConsumerWidget {
  const _AssignedComplaintsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complaintsAsync = ref.watch(assignedComplaintsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(assignedComplaintsProvider.future),
      child: complaintsAsync.when(
        data: (complaints) => _ComplaintList(
          complaints: complaints,
          emptyMessage: 'No open complaints are assigned to you.',
        ),
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error is ApiException ? error.message : 'Failed to load complaints.',
          onRetry: () => ref.invalidate(assignedComplaintsProvider),
        ),
      ),
    );
  }
}

class _AvailableComplaintsTab extends ConsumerWidget {
  const _AvailableComplaintsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complaintsAsync = ref.watch(availableComplaintsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(availableComplaintsProvider.future),
      child: complaintsAsync.when(
        data: (complaints) => _ComplaintList(
          complaints: complaints,
          emptyMessage: 'No open complaints are waiting in your department right now.',
        ),
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error is ApiException ? error.message : 'Failed to load complaints.',
          onRetry: () => ref.invalidate(availableComplaintsProvider),
        ),
      ),
    );
  }
}

class _ComplaintList extends StatelessWidget {
  const _ComplaintList({required this.complaints, required this.emptyMessage});

  final List<ComplaintSummary> complaints;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (complaints.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          EmptyView(message: emptyMessage, icon: Icons.confirmation_number_outlined),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: complaints.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => ComplaintCard(complaint: complaints[index]),
    );
  }
}
