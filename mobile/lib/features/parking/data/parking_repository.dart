import '../../../domain/parking.dart';

/// Data source for the Smart Parking module. Only the mock implementation
/// exists for now — the real backend has no parking endpoints yet (the
/// module's server side is IoT/MQTT work scheduled later in the proposal's
/// Gantt chart), so this app ships frontend-only against seeded data.
abstract class ParkingRepository {
  Future<List<ParkingSlot>> slots();

  Future<ParkingOverview> overview();

  /// Vehicles registered by the signed-in employee.
  Future<List<Vehicle>> myVehicles();

  /// Submits a new vehicle for admin approval (web dashboard).
  Future<Vehicle> registerVehicle({
    required String plate,
    required String model,
    required String color,
  });

  /// Unregistered-vehicle alerts from the entrance reader. Security only.
  Future<List<ParkingAlert>> alerts();

  Future<void> resolveAlert(int id);
}
