using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Ogdcl.Application.Tickets;

namespace Ogdcl.Api.Controllers;

[Route("api/categories")]
[Authorize]
public class CategoriesController : BaseApiController
{
    private readonly TicketService _tickets;

    public CategoriesController(TicketService tickets)
    {
        _tickets = tickets;
    }

    [HttpGet]
    public async Task<List<CategoryDto>> Get(CancellationToken ct) =>
        await _tickets.GetCategoriesAsync(ct);
}
