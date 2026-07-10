import 'enums.dart';

class User {
  const User({
    required this.id,
    required this.username,
    required this.displayName,
    required this.email,
    required this.role,
    this.department,
  });

  final int id;
  final String username;
  final String displayName;
  final String email;
  final UserRole role;
  final String? department;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        username: json['username'] as String,
        displayName: json['displayName'] as String,
        email: json['email'] as String,
        role: UserRole.fromJson(json['role'] as String),
        department: json['department'] as String?,
      );
}
