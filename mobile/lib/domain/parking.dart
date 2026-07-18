import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Live occupancy state of a single parking slot, as reported by the slot's
/// IoT sensor (proposal §6.2.1). [flagged] means the slot is occupied by a
/// vehicle the entrance reader could not match against the approved list.
enum ParkingSlotStatus {
  free,
  occupied,
  flagged;

  String get label => switch (this) {
        ParkingSlotStatus.free => 'Available',
        ParkingSlotStatus.occupied => 'Occupied',
        ParkingSlotStatus.flagged => 'Flagged',
      };

  Color get color => switch (this) {
        ParkingSlotStatus.free => AppColors.ok,
        ParkingSlotStatus.occupied => AppColors.accent,
        ParkingSlotStatus.flagged => AppColors.bad,
      };
}

/// Approval state of an employee-registered vehicle. New vehicles start as
/// [pending] until an admin approves them on the web dashboard (proposal §7:
/// "New vehicles need to be submitted by the employee and approved by an
/// admin before they can be used").
enum VehicleStatus {
  pending,
  approved,
  rejected;

  String get label => switch (this) {
        VehicleStatus.pending => 'Pending Approval',
        VehicleStatus.approved => 'Approved',
        VehicleStatus.rejected => 'Rejected',
      };

  Color get color => switch (this) {
        VehicleStatus.pending => AppColors.warn,
        VehicleStatus.approved => AppColors.ok,
        VehicleStatus.rejected => AppColors.bad,
      };
}

class ParkingSlot {
  const ParkingSlot({
    required this.id,
    required this.label,
    required this.zone,
    required this.status,
    this.plate,
  });

  final int id;

  /// Human label painted on the ground, e.g. "A-04".
  final String label;
  final String zone;
  final ParkingSlotStatus status;

  /// Plate of the vehicle currently in the slot, when known. For [flagged]
  /// slots this is whatever the entrance reader scanned.
  final String? plate;
}

class Vehicle {
  const Vehicle({
    required this.id,
    required this.plate,
    required this.model,
    required this.color,
    required this.status,
    required this.ownerId,
  });

  final int id;
  final String plate;
  final String model;
  final String color;
  final VehicleStatus status;
  final int ownerId;
}

/// An unregistered-vehicle event raised by the entrance reader
/// (proposal §6.2.2) — pushed to the security team's phones.
class ParkingAlert {
  const ParkingAlert({
    required this.id,
    required this.plate,
    required this.gate,
    required this.occurredAt,
    required this.resolved,
  });

  final int id;
  final String plate;
  final String gate;
  final DateTime occurredAt;
  final bool resolved;
}

/// Aggregate counts for the dashboard's parking stat card and the header
/// row of the parking screen.
class ParkingOverview {
  const ParkingOverview({
    required this.total,
    required this.free,
    required this.occupied,
    required this.flagged,
  });

  final int total;
  final int free;
  final int occupied;
  final int flagged;
}
