import '../../../core/network/api_client.dart';
import '../../../domain/category.dart';
import '../../../domain/enums.dart';
import '../../../domain/paged_result.dart';
import '../../../domain/ticket.dart';
import 'handler_option.dart';
import 'ticket_api.dart';

abstract class TicketRepository {
  Future<List<Category>> categories();

  Future<Ticket> create({required int categoryId, required String title, required String description});

  Future<List<TicketSummary>> mine();

  Future<List<TicketSummary>> assigned();

  Future<Ticket> byId(int id);

  Future<Ticket> updateStatus(int id, {required TicketStatus status, String? note});

  Future<Ticket> assign(int id, {required int handlerId});

  Future<Ticket> submitFeedback(int id, {required int rating, String? comment});

  Future<Attachment> uploadAttachment(int id, {required String filePath, required String fileName});

  Future<List<int>> downloadAttachment(int ticketId, int attachmentId);

  Future<PagedResult<TicketSummary>> adminTickets({TicketStatus? status, int page = 1, int pageSize = 20});

  /// Total ticket count per status, used for the admin dashboard's stat
  /// tiles — cheap because pageSize=1 still returns the full `total`.
  Future<int> adminTicketCount({TicketStatus? status});

  Future<List<HandlerOption>> activeHandlers();
}

class ApiTicketRepository implements TicketRepository {
  ApiTicketRepository(this._api, this._apiClient);

  final TicketApi _api;
  final ApiClient _apiClient;

  @override
  Future<List<Category>> categories() => _apiClient.guarded(() async {
        final res = await _api.categories();
        return (res.data as List)
            .map((e) => Category.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<Ticket> create({
    required int categoryId,
    required String title,
    required String description,
  }) =>
      _apiClient.guarded(() async {
        final res =
            await _api.create(categoryId: categoryId, title: title, description: description);
        return Ticket.fromJson(res.data as Map<String, dynamic>);
      });

  @override
  Future<List<TicketSummary>> mine() => _apiClient.guarded(() async {
        final res = await _api.mine();
        return (res.data as List)
            .map((e) => TicketSummary.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<List<TicketSummary>> assigned() => _apiClient.guarded(() async {
        final res = await _api.assigned();
        return (res.data as List)
            .map((e) => TicketSummary.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<Ticket> byId(int id) => _apiClient.guarded(() async {
        final res = await _api.byId(id);
        return Ticket.fromJson(res.data as Map<String, dynamic>);
      });

  @override
  Future<Ticket> updateStatus(int id, {required TicketStatus status, String? note}) =>
      _apiClient.guarded(() async {
        final res = await _api.updateStatus(id, status: status.toJson(), note: note);
        return Ticket.fromJson(res.data as Map<String, dynamic>);
      });

  @override
  Future<Ticket> assign(int id, {required int handlerId}) => _apiClient.guarded(() async {
        final res = await _api.assign(id, handlerId: handlerId);
        return Ticket.fromJson(res.data as Map<String, dynamic>);
      });

  @override
  Future<Ticket> submitFeedback(int id, {required int rating, String? comment}) =>
      _apiClient.guarded(() async {
        final res = await _api.feedback(id, rating: rating, comment: comment);
        return Ticket.fromJson(res.data as Map<String, dynamic>);
      });

  @override
  Future<Attachment> uploadAttachment(int id, {required String filePath, required String fileName}) =>
      _apiClient.guarded(() async {
        final res = await _api.uploadAttachment(id, filePath: filePath, fileName: fileName);
        return Attachment.fromJson(res.data as Map<String, dynamic>);
      });

  @override
  Future<List<int>> downloadAttachment(int ticketId, int attachmentId) =>
      _apiClient.guarded(() async {
        final res = await _api.downloadAttachment(ticketId, attachmentId);
        return res.data ?? const [];
      });

  @override
  Future<PagedResult<TicketSummary>> adminTickets({
    TicketStatus? status,
    int page = 1,
    int pageSize = 20,
  }) =>
      _apiClient.guarded(() async {
        final res = await _api.adminTickets(status: status?.toJson(), page: page, pageSize: pageSize);
        return PagedResult.fromJson(
          res.data as Map<String, dynamic>,
          (json) => TicketSummary.fromJson(json),
        );
      });

  @override
  Future<int> adminTicketCount({TicketStatus? status}) => _apiClient.guarded(() async {
        final res = await _api.adminTickets(status: status?.toJson(), page: 1, pageSize: 1);
        return (res.data as Map<String, dynamic>)['total'] as int;
      });

  @override
  Future<List<HandlerOption>> activeHandlers() => _apiClient.guarded(() async {
        final res = await _api.adminUsers(role: 'Handler');
        return (res.data as List)
            .map((e) => HandlerOption.fromJson(e as Map<String, dynamic>))
            .where((handler) => handler.isActive)
            .toList();
      });
}
