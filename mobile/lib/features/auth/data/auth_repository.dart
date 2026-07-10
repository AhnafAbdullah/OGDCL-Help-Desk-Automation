import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../../../domain/user.dart';
import 'auth_api.dart';

abstract class AuthRepository {
  Future<User> login(String username, String password);
  Future<User> currentUser();

  /// Used on app start: returns the signed-in user if a stored token is
  /// still valid (or refreshable), otherwise null — never throws.
  Future<User?> tryRestoreSession();
  Future<void> logout();
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api, this._apiClient, this._tokenStorage);

  final AuthApi _api;
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  @override
  Future<User> login(String username, String password) => _apiClient.guarded(() async {
        final response = await _api.login(username, password);
        final data = response.data as Map<String, dynamic>;
        await _tokenStorage.saveTokens(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
        );
        return User.fromJson(data['user'] as Map<String, dynamic>);
      });

  @override
  Future<User> currentUser() => _apiClient.guarded(() async {
        final response = await _api.me();
        return User.fromJson(response.data as Map<String, dynamic>);
      });

  @override
  Future<User?> tryRestoreSession() async {
    final token = await _tokenStorage.readAccessToken();
    if (token == null) return null;
    try {
      return await currentUser();
    } on ApiException {
      return null;
    }
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken != null) {
      try {
        await _api.logout(refreshToken);
      } catch (_) {
        // Best-effort server-side revoke; local session is cleared regardless.
      }
    }
    await _tokenStorage.clear();
  }
}
