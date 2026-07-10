/// A user-facing API failure. [message] is safe to show directly in a
/// SnackBar or error view — it's either the backend's `{ "error": "..." }`
/// message or a generic connectivity message.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}
