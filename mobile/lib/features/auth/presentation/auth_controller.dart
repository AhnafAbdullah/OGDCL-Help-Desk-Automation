import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../mock/mock_auth_repository.dart';
import '../data/auth_api.dart';
import '../data/auth_repository.dart';
import 'auth_state.dart';

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(apiClientProvider).dio));

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (Env.useMockBackend) return MockAuthRepository();
  return ApiAuthRepository(
    ref.watch(authApiProvider),
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  );
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final controller = AuthController(ref.watch(authRepositoryProvider));
  ref.read(apiClientProvider).onSessionExpired = controller.handleSessionExpired;
  controller.bootstrap();
  return controller;
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthInitial());

  final AuthRepository _repository;

  Future<void> bootstrap() async {
    state = const AuthLoading();
    final user = await _repository.tryRestoreSession();
    state = user == null ? const AuthUnauthenticated() : AuthAuthenticated(user);
  }

  Future<void> login(String username, String password) async {
    state = const AuthLoading();
    try {
      final user = await _repository.login(username, password);
      state = AuthAuthenticated(user);
    } on ApiException catch (e) {
      state = AuthUnauthenticated(error: e.message);
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthUnauthenticated();
  }

  /// Called by [ApiClient] when a refresh attempt fails on a 401.
  void handleSessionExpired() {
    if (state is AuthAuthenticated) {
      state = const AuthUnauthenticated(error: 'Your session expired. Please sign in again.');
    }
  }
}
