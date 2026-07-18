import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../domain/category.dart';
import '../../../domain/complaint.dart';
import '../../../domain/enums.dart';
import 'complaint_api.dart';

abstract class ComplaintRepository {
  Future<List<Category>> categories();

  Future<Complaint> create({
    required int categoryId,
    required String title,
    required String description,
    required ComplaintSeverity severity,
  });

  Future<List<ComplaintSummary>> mine();

  Future<List<ComplaintSummary>> assigned();

  /// Open complaints sitting in the current handler's own department,
  /// available for anyone there to pick up via [selfAssign].
  Future<List<ComplaintSummary>> available();

  Future<Complaint> byId(int id);

  Future<Complaint> updateStatus(int id, {required ComplaintStatus status, String? note});

  Future<Complaint> selfAssign(int id, {required int handlerId});

  Future<Complaint> submitFeedback(int id, {required int rating, String? comment});

  Future<Attachment> uploadAttachment(int id, {required String filePath, required String fileName});

  Future<List<int>> downloadAttachment(int complaintId, int attachmentId);
}

class ApiComplaintRepository implements ComplaintRepository {
  ApiComplaintRepository(this._api, this._apiClient);

  final ComplaintApi _api;
  final ApiClient _apiClient;

  @override
  Future<List<Category>> categories() => _apiClient.guarded(() async {
        final res = await _api.categories();
        return (res.data as List)
            .map((e) => Category.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<Complaint> create({
    required int categoryId,
    required String title,
    required String description,
    required ComplaintSeverity severity,
  }) =>
      _apiClient.guarded(() async {
        // The real backend has no concept of complainer-chosen severity yet
        // — it auto-derives priority from category. `severity` is only
        // honored against the mock backend; here it's silently ignored and
        // whatever the server computes comes back in the response instead.
        final res =
            await _api.create(categoryId: categoryId, title: title, description: description);
        return Complaint.fromJson(res.data as Map<String, dynamic>);
      });

  @override
  Future<List<ComplaintSummary>> mine() => _apiClient.guarded(() async {
        final res = await _api.mine();
        return (res.data as List)
            .map((e) => ComplaintSummary.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<List<ComplaintSummary>> assigned() => _apiClient.guarded(() async {
        final res = await _api.assigned();
        return (res.data as List)
            .map((e) => ComplaintSummary.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<List<ComplaintSummary>> available() async {
    // No endpoint exists for a non-admin to browse a department's open
    // queue on the current backend (only /api/admin/tickets, which is
    // Admin-gated, and Admin doesn't use this app) — nothing to call yet.
    throw ApiException(
      "Browsing available complaints isn't supported by the current backend yet.",
    );
  }

  @override
  Future<Complaint> byId(int id) => _apiClient.guarded(() async {
        final res = await _api.byId(id);
        return Complaint.fromJson(res.data as Map<String, dynamic>);
      });

  @override
  Future<Complaint> updateStatus(int id, {required ComplaintStatus status, String? note}) =>
      _apiClient.guarded(() async {
        final res = await _api.updateStatus(id, status: status.toJson(), note: note);
        return Complaint.fromJson(res.data as Map<String, dynamic>);
      });

  @override
  Future<Complaint> selfAssign(int id, {required int handlerId}) => _apiClient.guarded(() async {
        // The real backend's assign endpoint is Admin-only today, so this
        // will 403 for a Handler caller until that's relaxed server-side.
        final res = await _api.selfAssign(id, handlerId: handlerId);
        return Complaint.fromJson(res.data as Map<String, dynamic>);
      });

  @override
  Future<Complaint> submitFeedback(int id, {required int rating, String? comment}) =>
      _apiClient.guarded(() async {
        final res = await _api.feedback(id, rating: rating, comment: comment);
        return Complaint.fromJson(res.data as Map<String, dynamic>);
      });

  @override
  Future<Attachment> uploadAttachment(int id, {required String filePath, required String fileName}) =>
      _apiClient.guarded(() async {
        final res = await _api.uploadAttachment(id, filePath: filePath, fileName: fileName);
        return Attachment.fromJson(res.data as Map<String, dynamic>);
      });

  @override
  Future<List<int>> downloadAttachment(int complaintId, int attachmentId) =>
      _apiClient.guarded(() async {
        final res = await _api.downloadAttachment(complaintId, attachmentId);
        return res.data ?? const [];
      });
}
