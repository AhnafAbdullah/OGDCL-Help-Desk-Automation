using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;

namespace Ogdcl.Api.Controllers;

[ApiController]
public abstract class BaseApiController : ControllerBase
{
    protected int UserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
}
