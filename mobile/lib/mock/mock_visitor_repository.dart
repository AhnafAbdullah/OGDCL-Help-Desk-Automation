import '../core/network/api_exception.dart';
import '../domain/user.dart';
import '../domain/visitor.dart';
import '../features/visitors/data/visitor_repository.dart';
import 'mock_database.dart';

/// Serves the Visitor Entry screens from the seeded [MockDatabase],
/// including the OTP-to-guard and arrival/departure notification flows.
class MockVisitorRepository implements VisitorRepository {
  final _db = MockDatabase.instance;

  User get _actor {
    final user = _db.currentUser;
    if (user == null) throw ApiException('Not signed in.', statusCode: 401);
    return user;
  }

  @override
  Future<List<VisitorVisit>> myVisitors() async => _db.visitsHostedBy(_actor.id);

  @override
  Future<List<VisitorVisit>> gateVisits() async {
    _actor; // must be signed in
    return _db.gateVisits();
  }

  @override
  Future<VisitorVisit> register({
    required String visitorName,
    required String cnic,
    required String contact,
    required String purpose,
    required DateTime expectedArrival,
    required List<String> allowedZones,
  }) async {
    if (visitorName.trim().isEmpty) throw ApiException('Visitor name is required.');
    if (cnic.trim().isEmpty) throw ApiException('CNIC is required.');
    if (contact.trim().isEmpty) throw ApiException('Contact number is required.');
    if (purpose.trim().isEmpty) throw ApiException('Purpose of visit is required.');
    if (allowedZones.isEmpty) throw ApiException('Select at least one permitted zone.');
    return _db.registerVisitor(
      visitorName: visitorName.trim(),
      cnic: cnic.trim(),
      contact: contact.trim(),
      purpose: purpose.trim(),
      expectedArrival: expectedArrival,
      allowedZones: allowedZones,
      host: _actor,
    );
  }

  @override
  Future<VisitorVisit> verifyAndCheckIn({required String otp, required String rfidCard}) async {
    _actor; // must be signed in
    if (otp.trim().isEmpty) throw ApiException('Enter the visitor\'s code.');
    if (rfidCard.trim().isEmpty) throw ApiException('Enter the RFID card number.');
    if (!_db.hasPendingVisitWithOtp(otp)) {
      throw ApiException('No pending visit matches that code.');
    }
    return _db.checkInVisitor(otp: otp.trim(), rfidCard: rfidCard.trim().toUpperCase());
  }

  @override
  Future<VisitorVisit> checkOut(int visitId) async {
    _actor; // must be signed in
    return _db.checkOutVisitor(visitId);
  }
}
