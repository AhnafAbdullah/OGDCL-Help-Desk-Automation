import 'package:dio/dio.dart';

/// Raw HTTP calls for `/api/auth/*`. Kept dumb on purpose — parsing and
/// token persistence live in [AuthRepository].
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<Response> login(String username, String password) =>
      _dio.post('/auth/login', data: {'username': username, 'password': password});

  Future<Response> me() => _dio.get('/auth/me');

  Future<Response> logout(String refreshToken) =>
      _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
}
