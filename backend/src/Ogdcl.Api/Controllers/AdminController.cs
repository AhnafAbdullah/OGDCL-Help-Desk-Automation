using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Ogdcl.Application.Common;
using Ogdcl.Application.Tickets;
using Ogdcl.Domain;
using Ogdcl.Domain.Entities;

namespace Ogdcl.Api.Controllers;

public record DepartmentDto(int Id, string Name);
public record AdminUserDto(int Id, string Username, string DisplayName, UserRole Role, string? Department, bool IsActive);
public record AssignmentRuleDto(int Id, int CategoryId, string Category, int DepartmentId, string Department, TicketPriority DefaultPriority);
public record UpsertAssignmentRuleRequest(int CategoryId, int DepartmentId, TicketPriority DefaultPriority);
public record CreateCategoryRequest(string Name);

[Route("api/admin")]
[Authorize(Roles = "FloorAdmin,SuperAdmin")]
public class AdminController : BaseApiController
{
    private const string SuperOnly = "SuperAdmin";

    private readonly IAppDbContext _db;
    private readonly TicketService _tickets;

    public AdminController(IAppDbContext db, TicketService tickets)
    {
        _db = db;
        _tickets = tickets;
    }

    [HttpGet("departments")]
    public async Task<List<DepartmentDto>> Departments(CancellationToken ct) =>
        await _db.Departments.OrderBy(d => d.Name)
            .Select(d => new DepartmentDto(d.Id, d.Name)).ToListAsync(ct);

    // Floor admins only see users within their own department.
    [HttpGet("users")]
    public async Task<List<AdminUserDto>> Users([FromQuery] UserRole? role, CancellationToken ct)
    {
        var me = await _db.Users.FirstAsync(u => u.Id == UserId, ct);
        var query = _db.Users.Include(u => u.Department).AsQueryable();
        if (me.Role == UserRole.FloorAdmin)
            query = query.Where(u => u.DepartmentId == me.DepartmentId);
        if (role is not null)
            query = query.Where(u => u.Role == role);
        return await query.OrderBy(u => u.Username)
            .Select(u => new AdminUserDto(u.Id, u.Username, u.DisplayName, u.Role, u.Department!.Name, u.IsActive))
            .ToListAsync(ct);
    }

    [HttpGet("tickets")]
    public async Task<PagedResult<TicketSummaryDto>> Tickets(
        [FromQuery] TicketStatus? status, [FromQuery] int? categoryId, [FromQuery] int? departmentId,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        await _tickets.SearchForAdminAsync(UserId, status, categoryId, departmentId, page, pageSize, ct);

    [HttpGet("handler-stats")]
    public async Task<List<HandlerStatDto>> HandlerStats(CancellationToken ct) =>
        await _tickets.GetHandlerStatsAsync(UserId, ct);

    [HttpGet("assignment-rules")]
    public async Task<List<AssignmentRuleDto>> AssignmentRules(CancellationToken ct) =>
        await _db.AssignmentRules
            .Include(r => r.Category).Include(r => r.Department)
            .OrderBy(r => r.Category.Name)
            .Select(r => new AssignmentRuleDto(r.Id, r.CategoryId, r.Category.Name, r.DepartmentId, r.Department.Name, r.DefaultPriority))
            .ToListAsync(ct);

    // Global configuration is super-admin only.
    [HttpPost("assignment-rules")]
    [Authorize(Roles = SuperOnly)]
    public async Task<AssignmentRuleDto> UpsertAssignmentRule(UpsertAssignmentRuleRequest request, CancellationToken ct)
    {
        var category = await _db.ComplaintCategories.FirstOrDefaultAsync(c => c.Id == request.CategoryId, ct)
            ?? throw new AppValidationException("Category not found.");
        var department = await _db.Departments.FirstOrDefaultAsync(d => d.Id == request.DepartmentId, ct)
            ?? throw new AppValidationException("Department not found.");

        var rule = await _db.AssignmentRules.FirstOrDefaultAsync(r => r.CategoryId == category.Id, ct);
        if (rule is null)
        {
            rule = new AssignmentRule { CategoryId = category.Id };
            _db.AssignmentRules.Add(rule);
        }
        rule.DepartmentId = department.Id;
        rule.DefaultPriority = request.DefaultPriority;
        await _db.SaveChangesAsync(ct);

        return new AssignmentRuleDto(rule.Id, category.Id, category.Name, department.Id, department.Name, rule.DefaultPriority);
    }

    [HttpPost("categories")]
    [Authorize(Roles = SuperOnly)]
    public async Task<CategoryDto> CreateCategory(CreateCategoryRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
            throw new AppValidationException("Category name is required.");

        var name = request.Name.Trim();
        if (await _db.ComplaintCategories.AnyAsync(c => c.Name.ToLower() == name.ToLower(), ct))
            throw new AppValidationException("A category with this name already exists.");

        var category = new ComplaintCategory { Name = name };
        _db.ComplaintCategories.Add(category);
        await _db.SaveChangesAsync(ct);
        return new CategoryDto(category.Id, category.Name);
    }
}
