import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/providers.dart';
import '../../../domain/category.dart';
import '../../../domain/enums.dart';
import '../../../domain/paged_result.dart';
import '../../../domain/ticket.dart';
import '../../../mock/mock_ticket_repository.dart';
import '../data/handler_option.dart';
import '../data/ticket_api.dart';
import '../data/ticket_repository.dart';

final ticketApiProvider = Provider<TicketApi>((ref) => TicketApi(ref.watch(apiClientProvider).dio));

final ticketRepositoryProvider = Provider<TicketRepository>((ref) {
  if (Env.useMockBackend) return MockTicketRepository();
  return ApiTicketRepository(ref.watch(ticketApiProvider), ref.watch(apiClientProvider));
});

final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(ticketRepositoryProvider).categories();
});

final myTicketsProvider = FutureProvider.autoDispose<List<TicketSummary>>((ref) {
  return ref.watch(ticketRepositoryProvider).mine();
});

final assignedTicketsProvider = FutureProvider.autoDispose<List<TicketSummary>>((ref) {
  return ref.watch(ticketRepositoryProvider).assigned();
});

final activeHandlersProvider = FutureProvider.autoDispose<List<HandlerOption>>((ref) {
  return ref.watch(ticketRepositoryProvider).activeHandlers();
});

final ticketDetailProvider = FutureProvider.autoDispose.family<Ticket, int>((ref, id) {
  return ref.watch(ticketRepositoryProvider).byId(id);
});

class AdminTicketFilter {
  const AdminTicketFilter({this.status, this.page = 1, this.pageSize = 20});

  final TicketStatus? status;
  final int page;
  final int pageSize;

  @override
  bool operator ==(Object other) =>
      other is AdminTicketFilter &&
      other.status == status &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(status, page, pageSize);
}

final adminTicketsProvider =
    FutureProvider.autoDispose.family<PagedResult<TicketSummary>, AdminTicketFilter>((ref, filter) {
  return ref.watch(ticketRepositoryProvider).adminTickets(
        status: filter.status,
        page: filter.page,
        pageSize: filter.pageSize,
      );
});

/// Ticket totals per status for the admin dashboard's stat tiles.
final adminTicketCountsProvider = FutureProvider.autoDispose<Map<TicketStatus?, int>>((ref) async {
  final repo = ref.watch(ticketRepositoryProvider);
  final statuses = <TicketStatus?>[null, ...TicketStatus.values];
  final counts = await Future.wait(statuses.map((s) => repo.adminTicketCount(status: s)));
  return Map.fromIterables(statuses, counts);
});
