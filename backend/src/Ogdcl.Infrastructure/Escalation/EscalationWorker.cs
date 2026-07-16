using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Ogdcl.Application.Tickets;

namespace Ogdcl.Infrastructure.Escalation;

/// <summary>
/// Anti-starvation background service. On a fixed cadence it asks the ticket
/// service to escalate any complaint whose severity timer has elapsed — bumping
/// its severity, flagging it overdue, restarting the timer, and alerting the
/// relevant handlers and admins.
/// </summary>
public class EscalationWorker : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly EscalationOptions _options;
    private readonly ILogger<EscalationWorker> _logger;

    public EscalationWorker(IServiceScopeFactory scopeFactory, EscalationOptions options, ILogger<EscalationWorker> logger)
    {
        _scopeFactory = scopeFactory;
        _options = options;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var interval = TimeSpan.FromSeconds(Math.Max(5, _options.CheckIntervalSeconds));
        using var timer = new PeriodicTimer(interval);

        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                var tickets = scope.ServiceProvider.GetRequiredService<TicketService>();
                var escalated = await tickets.EscalateDueTicketsAsync(stoppingToken);
                if (escalated > 0)
                    _logger.LogInformation("Escalated {Count} overdue complaint(s).", escalated);
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                // Never let a single failed sweep kill the worker.
                _logger.LogError(ex, "Escalation sweep failed.");
            }
        }
    }
}
