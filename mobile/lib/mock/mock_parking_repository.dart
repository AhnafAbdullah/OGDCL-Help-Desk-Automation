import '../core/network/api_exception.dart';
import '../domain/parking.dart';
import '../domain/user.dart';
import '../features/parking/data/parking_repository.dart';
import 'mock_database.dart';

/// Serves the Smart Parking screens from the seeded [MockDatabase] — the
/// stand-in for what will eventually be live MQTT sensor data.
class MockParkingRepository implements ParkingRepository {
  final _db = MockDatabase.instance;

  User get _actor {
    final user = _db.currentUser;
    if (user == null) throw ApiException('Not signed in.', statusCode: 401);
    return user;
  }

  @override
  Future<List<ParkingSlot>> slots() async => _db.parkingSlots();

  @override
  Future<ParkingOverview> overview() async => _db.parkingOverview();

  @override
  Future<List<Vehicle>> myVehicles() async => _db.vehiclesFor(_actor.id);

  @override
  Future<Vehicle> registerVehicle({
    required String plate,
    required String model,
    required String color,
  }) async {
    if (plate.trim().isEmpty) throw ApiException('Plate number is required.');
    if (model.trim().isEmpty) throw ApiException('Vehicle model is required.');
    final existing = _db.vehiclesFor(_actor.id);
    if (existing.any((v) => v.plate.toLowerCase() == plate.trim().toLowerCase())) {
      throw ApiException('You have already registered this plate number.');
    }
    return _db.registerVehicle(
      plate: plate.trim().toUpperCase(),
      model: model.trim(),
      color: color.trim(),
      owner: _actor,
    );
  }

  @override
  Future<List<ParkingAlert>> alerts() async => _db.parkingAlerts();

  @override
  Future<void> resolveAlert(int id) async => _db.resolveParkingAlert(id);
}
