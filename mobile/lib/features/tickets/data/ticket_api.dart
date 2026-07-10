import 'package:dio/dio.dart';

/// Raw HTTP calls for `/api/tickets/*`, `/api/categories`, and the
/// admin-only ticket/user endpoints the mobile app reuses for the "All
/// Tickets" tab and handler reassignment.
class TicketApi {
  TicketApi(this._dio);

  final Dio _dio;

  Future<Response> categories() => _dio.get('/categories');

  Future<Response> create({
    required int categoryId,
    required String title,
    required String description,
  }) =>
      _dio.post('/tickets', data: {
        'categoryId': categoryId,
        'title': title,
        'description': description,
      });

  Future<Response> mine() => _dio.get('/tickets/mine');

  Future<Response> assigned() => _dio.get('/tickets/assigned');

  Future<Response> byId(int id) => _dio.get('/tickets/$id');

  Future<Response> updateStatus(int id, {required String status, String? note}) =>
      _dio.patch('/tickets/$id/status', data: {'status': status, 'note': note});

  Future<Response> assign(int id, {required int handlerId}) =>
      _dio.patch('/tickets/$id/assign', data: {'handlerId': handlerId});

  Future<Response> feedback(int id, {required int rating, String? comment}) =>
      _dio.post('/tickets/$id/feedback', data: {'rating': rating, 'comment': comment});

  Future<Response> uploadAttachment(
    int id, {
    required String filePath,
    required String fileName,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    return _dio.post('/tickets/$id/attachments', data: formData);
  }

  Future<Response<List<int>>> downloadAttachment(int ticketId, int attachmentId) =>
      _dio.get<List<int>>(
        '/tickets/$ticketId/attachments/$attachmentId',
        options: Options(responseType: ResponseType.bytes),
      );

  Future<Response> adminTickets({
    String? status,
    int page = 1,
    int pageSize = 20,
  }) =>
      _dio.get('/admin/tickets', queryParameters: {
        if (status != null) 'status': status,
        'page': page,
        'pageSize': pageSize,
      });

  Future<Response> adminUsers({String? role}) =>
      _dio.get('/admin/users', queryParameters: {if (role != null) 'role': role});
}
