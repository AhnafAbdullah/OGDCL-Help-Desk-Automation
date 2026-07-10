import '../core/network/api_exception.dart';
import '../domain/user.dart';
import '../features/auth/data/auth_repository.dart';
import 'mock_database.dart';

/// Demo login: validates against the same seeded username/password/role
/// combinations the real backend's dev seeder uses, entirely in memory.
class MockAuthRepository implements AuthRepository {
  final _db = MockDatabase.instance;

  @override
  Future<User> login(String username, String password) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final account = _db.accountByCredentials(username, password);
    if (account == null) {
      throw ApiException('Invalid username or password.');
    }
    final user = account.toUser();
    _db.currentUser = user;
    return user;
  }

  @override
  Future<User> currentUser() async {
    final user = _db.currentUser;
    if (user == null) throw ApiException('Not signed in.', statusCode: 401);
    return user;
  }

  @override
  Future<User?> tryRestoreSession() async => _db.currentUser;

  @override
  Future<void> logout() async {
    _db.currentUser = null;
  }
}
