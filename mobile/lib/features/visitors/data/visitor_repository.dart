import '../../../domain/visitor.dart';

/// Data source for the Visitor Entry Management module. Only the mock
/// implementation exists for now — the real backend has no visitor
/// endpoints yet (OTP/RFID server work is scheduled later in the
/// proposal's Gantt chart), so this app ships frontend-only against
/// seeded data.
abstract class VisitorRepository {
  /// Visits hosted by the signed-in employee, newest first.
  Future<List<VisitorVisit>> myVisitors();

  /// Every visit the gate desk cares about. Security only.
  Future<List<VisitorVisit>> gateVisits();

  /// Pre-registers a guest and sends the generated gate code to the
  /// guards on duty.
  Future<VisitorVisit> register({
    required String visitorName,
    required String cnic,
    required String contact,
    required String purpose,
    required DateTime expectedArrival,
    required List<String> allowedZones,
  });

  /// Gate-desk arrival flow: verifies the code the visitor presented and,
  /// if valid, checks them in and links the issued RFID card.
  Future<VisitorVisit> verifyAndCheckIn({required String otp, required String rfidCard});

  /// Gate-desk departure flow: collects and deactivates the card, closes
  /// the visit record.
  Future<VisitorVisit> checkOut(int visitId);
}
