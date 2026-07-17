import 'enums.dart';

class User {
  const User({
    required this.id,
    required this.username,
    required this.displayName,
    required this.email,
    required this.role,
    this.department,
    this.designation,
  });

  final int id;
  final String username;
  final String displayName;
  final String email;
  final UserRole role;
  final String? department;

  /// Job title shown on the profile header (e.g. "IT Support Officer").
  /// The real backend's `UserDto` has no such field yet, so this falls
  /// back to the role label when parsed from a real API response.
  final String? designation;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        username: json['username'] as String,
        displayName: json['displayName'] as String,
        email: json['email'] as String,
        role: UserRole.fromJson(json['role'] as String),
        department: json['department'] as String?,
        designation: json['designation'] as String?,
      );
}
