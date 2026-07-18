import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/visitor.dart';
import '../../../mock/mock_visitor_repository.dart';
import '../data/visitor_repository.dart';

/// Always the mock for now — no real visitor endpoints exist yet (see
/// [VisitorRepository]), so unlike complaints there is no Env switch here.
final visitorRepositoryProvider = Provider<VisitorRepository>((ref) => MockVisitorRepository());

final myVisitorsProvider = FutureProvider.autoDispose<List<VisitorVisit>>((ref) {
  return ref.watch(visitorRepositoryProvider).myVisitors();
});

final gateVisitsProvider = FutureProvider.autoDispose<List<VisitorVisit>>((ref) {
  return ref.watch(visitorRepositoryProvider).gateVisits();
});
