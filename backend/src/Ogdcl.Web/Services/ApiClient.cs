using System.Net.Http.Headers;
using System.Text.Json;
using System.Text.Json.Serialization;
using Ogdcl.Application.Auth;
using Ogdcl.Application.Common;
using Ogdcl.Application.Notifications;
using Ogdcl.Application.Tickets;
using Ogdcl.Application.Visits;
using Ogdcl.Domain;

namespace Ogdcl.Web.Services;

// Mirrors of API-project DTOs that live outside Ogdcl.Application.
public record DepartmentDto(int Id, string Name);
public record AdminUserDto(int Id, string Username, string DisplayName, UserRole Role, string? Department, bool IsActive);
public record AssignmentRuleDto(int Id, int CategoryId, string Category, int DepartmentId, string Department, TicketPriority DefaultPriority);

public class ApiException : Exception
{
    public int StatusCode { get; }

    public ApiException(int statusCode, string message) : base(message)
    {
        StatusCode = statusCode;
    }
}

/// <summary>Typed client for the OGDCL REST API; attaches the circuit's JWT.</summary>
public class ApiClient
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web)
    {
        Converters = { new JsonStringEnumConverter() },
    };

    private readonly HttpClient _http;
    private readonly AuthState _auth;

    public ApiClient(HttpClient http, AuthState auth)
    {
        _http = http;
        _auth = auth;
    }

    /// <summary>API root (e.g. http://localhost:5080/), for building direct file-download links.</summary>
    public string BaseUrl => _http.BaseAddress!.ToString();

    // Auth
    public Task<AuthResponse> LoginAsync(string username, string password) =>
        PostAsync<AuthResponse>("api/auth/login", new LoginRequest(username, password), anonymous: true);

    // Help desk
    public Task<List<CategoryDto>> GetCategoriesAsync() => GetAsync<List<CategoryDto>>("api/categories");
    public Task<TicketDto> CreateTicketAsync(CreateTicketRequest request) => PostAsync<TicketDto>("api/tickets", request);
    public Task<List<TicketSummaryDto>> GetMyTicketsAsync() => GetAsync<List<TicketSummaryDto>>("api/tickets/mine");
    public Task<List<TicketSummaryDto>> GetAssignedTicketsAsync() => GetAsync<List<TicketSummaryDto>>("api/tickets/assigned");
    public Task<List<TicketSummaryDto>> GetAvailableTicketsAsync() => GetAsync<List<TicketSummaryDto>>("api/tickets/available");
    public Task<List<TicketSummaryDto>> GetPendingApprovalsAsync() => GetAsync<List<TicketSummaryDto>>("api/tickets/pending-approvals");
    public Task<TicketDto> GetTicketAsync(int id) => GetAsync<TicketDto>($"api/tickets/{id}");

    public Task<TicketDto> UpdateTicketStatusAsync(int id, TicketStatus status, string? note) =>
        SendAsync<TicketDto>(HttpMethod.Patch, $"api/tickets/{id}/status", new UpdateTicketStatusRequest(status, note));

    public Task<TicketDto> AcceptTicketAsync(int id) => PostAsync<TicketDto>($"api/tickets/{id}/accept", body: null);
    public Task<TicketDto> RejectTicketAsync(int id, string? reason) => PostAsync<TicketDto>($"api/tickets/{id}/reject", new RejectRequest(reason));
    public Task<TicketDto> ApproveTicketAsync(int id) => PostAsync<TicketDto>($"api/tickets/{id}/approve", body: null);
    public Task<TicketDto> RejectApprovalAsync(int id, string? reason) => PostAsync<TicketDto>($"api/tickets/{id}/reject-approval", new RejectRequest(reason));

    public Task<TicketDto> AssignTicketAsync(int id, int handlerId) =>
        SendAsync<TicketDto>(HttpMethod.Patch, $"api/tickets/{id}/assign", new AssignTicketRequest(handlerId));

    public Task<TicketDto> AddFeedbackAsync(int id, int rating, string? comment) =>
        PostAsync<TicketDto>($"api/tickets/{id}/feedback", new TicketFeedbackRequest(rating, comment));

    public async Task<AttachmentDto> UploadAttachmentAsync(int ticketId, string fileName, string contentType, Stream content)
    {
        using var form = new MultipartFormDataContent();
        var fileContent = new StreamContent(content);
        fileContent.Headers.ContentType = new MediaTypeHeaderValue(contentType);
        form.Add(fileContent, "file", fileName);

        var request = new HttpRequestMessage(HttpMethod.Post, $"api/tickets/{ticketId}/attachments") { Content = form };
        if (_auth.Token is not null)
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _auth.Token);

        var response = await _http.SendAsync(request);
        await EnsureSuccessAsync(response);
        return (await response.Content.ReadFromJsonAsync<AttachmentDto>(Json))!;
    }

    // Visits
    public Task<VisitDto> RegisterVisitAsync(RegisterVisitRequest request) => PostAsync<VisitDto>("api/visits", request);
    public Task<List<VisitDto>> GetMyVisitsAsync() => GetAsync<List<VisitDto>>("api/visits/mine");
    public Task<List<VisitDto>> GetPendingVisitsAsync() => GetAsync<List<VisitDto>>("api/visits/pending");
    public Task<List<VisitDto>> GetActiveVisitsAsync() => GetAsync<List<VisitDto>>("api/visits/active");
    public Task<VisitDto> VerifyOtpAsync(int id, string code) => PostAsync<VisitDto>($"api/visits/{id}/verify-otp", new VerifyOtpRequest(code));
    public Task<VisitDto> IssueCardAsync(int id, string cardUid) => PostAsync<VisitDto>($"api/visits/{id}/issue-card", new IssueCardRequest(cardUid));
    public Task<VisitDto> CloseVisitAsync(int id) => PostAsync<VisitDto>($"api/visits/{id}/close", body: null);
    public Task<VisitDto> CancelVisitAsync(int id) => PostAsync<VisitDto>($"api/visits/{id}/cancel", body: null);
    public Task<VisitDto> ResendOtpAsync(int id) => PostAsync<VisitDto>($"api/visits/{id}/resend-otp", body: null);

    // Zones
    public Task<List<ZoneDto>> GetZonesAsync() => GetAsync<List<ZoneDto>>("api/zones");
    public Task<ZoneDto> CreateZoneAsync(string name, bool isRestricted) =>
        PostAsync<ZoneDto>("api/zones", new { name, isRestricted });

    // Notifications
    public Task<List<NotificationDto>> GetNotificationsAsync(bool unreadOnly = false) =>
        GetAsync<List<NotificationDto>>($"api/notifications?unreadOnly={unreadOnly}");

    public async Task MarkNotificationReadAsync(int id) =>
        await SendRawAsync(HttpMethod.Post, $"api/notifications/{id}/read", body: null);

    // Admin
    public Task<List<DepartmentDto>> GetDepartmentsAsync() => GetAsync<List<DepartmentDto>>("api/admin/departments");
    public Task<List<AdminUserDto>> GetUsersAsync(UserRole? role = null) =>
        GetAsync<List<AdminUserDto>>($"api/admin/users{(role is null ? "" : $"?role={role}")}");

    public Task<PagedResult<TicketSummaryDto>> SearchTicketsAsync(TicketStatus? status, int page = 1, int pageSize = 20)
    {
        var query = $"page={page}&pageSize={pageSize}" + (status is null ? "" : $"&status={status}");
        return GetAsync<PagedResult<TicketSummaryDto>>($"api/admin/tickets?{query}");
    }

    public Task<List<HandlerStatDto>> GetHandlerStatsAsync() => GetAsync<List<HandlerStatDto>>("api/admin/handler-stats");
    public Task<List<AssignmentRuleDto>> GetRulesAsync() => GetAsync<List<AssignmentRuleDto>>("api/admin/assignment-rules");
    public Task<AssignmentRuleDto> UpsertRuleAsync(int categoryId, int departmentId, TicketPriority defaultPriority) =>
        PostAsync<AssignmentRuleDto>("api/admin/assignment-rules", new { categoryId, departmentId, defaultPriority });

    public Task<CategoryDto> CreateCategoryAsync(string name) =>
        PostAsync<CategoryDto>("api/admin/categories", new { name });

    // Plumbing
    private Task<T> GetAsync<T>(string path) => SendAsync<T>(HttpMethod.Get, path, body: null);

    private Task<T> PostAsync<T>(string path, object? body, bool anonymous = false) =>
        SendAsync<T>(HttpMethod.Post, path, body, anonymous);

    private async Task<T> SendAsync<T>(HttpMethod method, string path, object? body, bool anonymous = false)
    {
        var response = await SendRawAsync(method, path, body, anonymous);
        return (await response.Content.ReadFromJsonAsync<T>(Json))!;
    }

    private async Task<HttpResponseMessage> SendRawAsync(HttpMethod method, string path, object? body, bool anonymous = false)
    {
        var request = new HttpRequestMessage(method, path);
        if (body is not null)
            request.Content = JsonContent.Create(body, options: Json);
        if (!anonymous && _auth.Token is not null)
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _auth.Token);

        var response = await _http.SendAsync(request);
        await EnsureSuccessAsync(response);
        return response;
    }

    private static async Task EnsureSuccessAsync(HttpResponseMessage response)
    {
        if (response.IsSuccessStatusCode)
            return;

        var message = "The request failed.";
        try
        {
            var payload = await response.Content.ReadFromJsonAsync<Dictionary<string, string>>(Json);
            if (payload is not null && payload.TryGetValue("error", out var error))
                message = error;
        }
        catch (JsonException)
        {
            // non-JSON error body; keep the generic message
        }
        throw new ApiException((int)response.StatusCode, message);
    }
}
