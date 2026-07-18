import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Lifecycle of a visit record (proposal §6.3): the host employee
/// pre-registers the guest, the gate guard verifies the OTP and issues an
/// RFID card on arrival, and collects/deactivates the card on departure.
enum VisitStatus {
  preRegistered,
  checkedIn,
  checkedOut;

  String get label => switch (this) {
        VisitStatus.preRegistered => 'Pre-Registered',
        VisitStatus.checkedIn => 'On Site',
        VisitStatus.checkedOut => 'Departed',
      };

  Color get color => switch (this) {
        VisitStatus.preRegistered => AppColors.warn,
        VisitStatus.checkedIn => AppColors.accent,
        VisitStatus.checkedOut => AppColors.neutral,
      };
}

/// Building zones a visitor can be permitted into. A fixed demo list — the
/// real system would load these from the backend where the admin manages
/// them (proposal §11: admin manages "RFID zones").
const List<String> kVisitorZones = [
  'Reception',
  'Admin Block',
  'IT Wing',
  'Finance Wing',
  'Conference Hall',
  'Cafeteria',
];

/// One RFID scanner read for a visitor's card (proposal §6.3.3). A denied
/// read is a zone violation and raises alerts to security and the admin.
class ZoneEvent {
  const ZoneEvent({
    required this.zone,
    required this.occurredAt,
    required this.allowed,
  });

  final String zone;
  final DateTime occurredAt;
  final bool allowed;
}

class VisitorVisit {
  const VisitorVisit({
    required this.id,
    required this.visitorName,
    required this.cnic,
    required this.contact,
    required this.purpose,
    required this.hostId,
    required this.hostName,
    required this.expectedArrival,
    required this.allowedZones,
    required this.status,
    required this.otp,
    this.rfidCard,
    this.checkInAt,
    this.checkOutAt,
    this.zoneEvents = const [],
  });

  final int id;
  final String visitorName;
  final String cnic;
  final String contact;
  final String purpose;
  final int hostId;
  final String hostName;
  final DateTime expectedArrival;
  final List<String> allowedZones;
  final VisitStatus status;

  /// The time-limited numeric gate code. Generated at registration and sent
  /// to the guard on duty (proposal §6.3.2) — the host never needs it.
  final String otp;

  /// Physical card linked at check-in, e.g. "RFID-1043". Null until the
  /// guard issues one, and again after departure when it's deactivated.
  final String? rfidCard;

  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final List<ZoneEvent> zoneEvents;

  bool get hasViolation => zoneEvents.any((e) => !e.allowed);
}
