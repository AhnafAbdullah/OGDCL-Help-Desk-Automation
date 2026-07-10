import 'package:dio/dio.dart';

class NotificationApi {
  NotificationApi(this._dio);

  final Dio _dio;

  Future<Response> list({bool unreadOnly = false}) =>
      _dio.get('/notifications', queryParameters: {'unreadOnly': unreadOnly});

  Future<Response> markRead(int id) => _dio.post('/notifications/$id/read');
}
