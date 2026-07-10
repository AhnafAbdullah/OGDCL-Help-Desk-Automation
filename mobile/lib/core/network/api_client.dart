import 'package:dio/dio.dart';

import '../config/env.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Thin wrapper around [Dio] that attaches the JWT to every request and
/// transparently refreshes it on a 401 (queuing concurrent requests so only
/// one refresh call is ever in flight).
class ApiClient {
  ApiClient(this._tokenStorage) {
    _dio = Dio(BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 30),
    ));

    // No interceptors: used for the refresh call itself and for retrying a
    // request after refresh, so neither can re-trigger this class's queue.
    _plainDio = Dio(BaseOptions(baseUrl: Env.apiBaseUrl));

    _dio.interceptors.add(QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokenStorage.readAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final isUnauthorized = error.response?.statusCode == 401;
        if (!isUnauthorized) {
          handler.next(error);
          return;
        }

        final newAccessToken = await _refreshAccessToken();
        if (newAccessToken == null) {
          await _tokenStorage.clear();
          onSessionExpired?.call();
          handler.next(error);
          return;
        }

        try {
          final retryOptions = error.requestOptions;
          retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
          final response = await _plainDio.fetch(retryOptions);
          handler.resolve(response);
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
      },
    ));
  }

  late final Dio _dio;
  late final Dio _plainDio;
  final TokenStorage _tokenStorage;

  /// Invoked when a refresh attempt fails, so the app can drop back to login.
  void Function()? onSessionExpired;

  Dio get dio => _dio;

  Future<String?> _refreshAccessToken() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) return null;

    try {
      final response = await _plainDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = response.data as Map<String, dynamic>;
      final accessToken = data['accessToken'] as String;
      final newRefreshToken = data['refreshToken'] as String;
      await _tokenStorage.saveTokens(accessToken: accessToken, refreshToken: newRefreshToken);
      return accessToken;
    } on DioException {
      return null;
    }
  }

  /// Runs [action] and converts any [DioException] into an [ApiException]
  /// carrying the backend's `{ "error": "..." }` message.
  Future<T> guarded<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  ApiException toApiException(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['error'] is String) {
      return ApiException(data['error'] as String, statusCode: error.response?.statusCode);
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return ApiException('Could not reach the server. Check your connection and try again.');
      default:
        return ApiException(
          error.response?.statusMessage ?? 'Something went wrong. Please try again.',
          statusCode: error.response?.statusCode,
        );
    }
  }
}
