import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/parking.dart';
import '../../../mock/mock_parking_repository.dart';
import '../data/parking_repository.dart';

/// Always the mock for now — no real parking endpoints exist yet (see
/// [ParkingRepository]), so unlike complaints there is no Env switch here.
final parkingRepositoryProvider = Provider<ParkingRepository>((ref) => MockParkingRepository());

final parkingSlotsProvider = FutureProvider.autoDispose<List<ParkingSlot>>((ref) {
  return ref.watch(parkingRepositoryProvider).slots();
});

final parkingOverviewProvider = FutureProvider.autoDispose<ParkingOverview>((ref) {
  return ref.watch(parkingRepositoryProvider).overview();
});

final myVehiclesProvider = FutureProvider.autoDispose<List<Vehicle>>((ref) {
  return ref.watch(parkingRepositoryProvider).myVehicles();
});

final parkingAlertsProvider = FutureProvider.autoDispose<List<ParkingAlert>>((ref) {
  return ref.watch(parkingRepositoryProvider).alerts();
});
