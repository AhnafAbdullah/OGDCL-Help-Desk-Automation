using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Ogdcl.Application.Common;
using Ogdcl.Application.Visits;
using Ogdcl.Domain.Entities;

namespace Ogdcl.Api.Controllers;

public record CreateZoneRequest(string Name, bool IsRestricted);

[Route("api/zones")]
[Authorize]
public class ZonesController : BaseApiController
{
    private readonly IAppDbContext _db;

    public ZonesController(IAppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<List<ZoneDto>> Get(CancellationToken ct) =>
        await _db.Zones
            .OrderBy(z => z.Name)
            .Select(z => new ZoneDto(z.Id, z.Name, z.IsRestricted))
            .ToListAsync(ct);

    [HttpPost]
    [Authorize(Roles = "SuperAdmin")]
    public async Task<ZoneDto> Create(CreateZoneRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
            throw new AppValidationException("Zone name is required.");

        var zone = new Zone { Name = request.Name.Trim(), IsRestricted = request.IsRestricted };
        _db.Zones.Add(zone);
        await _db.SaveChangesAsync(ct);
        return new ZoneDto(zone.Id, zone.Name, zone.IsRestricted);
    }
}
