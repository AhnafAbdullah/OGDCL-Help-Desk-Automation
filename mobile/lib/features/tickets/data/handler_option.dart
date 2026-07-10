/// A handler as listed by `GET /api/admin/users?role=Handler`, used to
/// populate the admin's reassignment dropdown.
class HandlerOption {
  const HandlerOption({
    required this.id,
    required this.displayName,
    required this.department,
    required this.isActive,
  });

  final int id;
  final String displayName;
  final String? department;
  final bool isActive;

  factory HandlerOption.fromJson(Map<String, dynamic> json) => HandlerOption(
        id: json['id'] as int,
        displayName: json['displayName'] as String,
        department: json['department'] as String?,
        isActive: json['isActive'] as bool,
      );
}
