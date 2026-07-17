import 'package:dio/dio.dart';

/// Raw HTTP calls for `/api/tickets/*` and `/api/categories`. Kept dumb on
/// purpose — parsing and business rules live in [ComplaintRepository].
///
/// URL paths and JSON keys intentionally still say "ticket" — that's the
/// real backend's wire contract, which this app doesn't control. Only the
/// in-app Dart/UI terminology was renamed to "complaint".
class ComplaintApi {
  ComplaintApi(this._dio);

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

  /// Real backend only allows Admin to call this — a Handler self-assign
  /// against the real API will 403 until that endpoint's permission
  /// check is updated server-side. Fully supported in mock mode.
  Future<Response> selfAssign(int id, {required int handlerId}) =>
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
}
