using Ogdcl.Application.Common;

namespace Ogdcl.Api.Middleware;

public class ExceptionHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionHandlingMiddleware> _logger;

    public ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            var (status, message) = ex switch
            {
                NotFoundException => (StatusCodes.Status404NotFound, ex.Message),
                AppValidationException => (StatusCodes.Status400BadRequest, ex.Message),
                ForbiddenException => (StatusCodes.Status403Forbidden, ex.Message),
                UnauthorizedException => (StatusCodes.Status401Unauthorized, ex.Message),
                NotSupportedException => (StatusCodes.Status400BadRequest, ex.Message),
                _ => (StatusCodes.Status500InternalServerError, "An unexpected error occurred."),
            };

            if (status == StatusCodes.Status500InternalServerError)
                _logger.LogError(ex, "Unhandled exception on {Method} {Path}", context.Request.Method, context.Request.Path);

            context.Response.StatusCode = status;
            await context.Response.WriteAsJsonAsync(new { error = message });
        }
    }
}
