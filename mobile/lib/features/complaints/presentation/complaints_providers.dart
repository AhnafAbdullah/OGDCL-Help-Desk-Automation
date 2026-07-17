import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/providers.dart';
import '../../../domain/category.dart';
import '../../../domain/complaint.dart';
import '../../../mock/mock_complaint_repository.dart';
import '../data/complaint_api.dart';
import '../data/complaint_repository.dart';

final complaintApiProvider =
    Provider<ComplaintApi>((ref) => ComplaintApi(ref.watch(apiClientProvider).dio));

final complaintRepositoryProvider = Provider<ComplaintRepository>((ref) {
  if (Env.useMockBackend) return MockComplaintRepository();
  return ApiComplaintRepository(ref.watch(complaintApiProvider), ref.watch(apiClientProvider));
});

final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(complaintRepositoryProvider).categories();
});

final myComplaintsProvider = FutureProvider.autoDispose<List<ComplaintSummary>>((ref) {
  return ref.watch(complaintRepositoryProvider).mine();
});

final assignedComplaintsProvider = FutureProvider.autoDispose<List<ComplaintSummary>>((ref) {
  return ref.watch(complaintRepositoryProvider).assigned();
});

/// Open complaints in the current handler's department, available to pick up.
final availableComplaintsProvider = FutureProvider.autoDispose<List<ComplaintSummary>>((ref) {
  return ref.watch(complaintRepositoryProvider).available();
});

final complaintDetailProvider = FutureProvider.autoDispose.family<Complaint, int>((ref, id) {
  return ref.watch(complaintRepositoryProvider).byId(id);
});
