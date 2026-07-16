using Ogdcl.Domain;

namespace Ogdcl.Application.Tickets;

/// <summary>
/// Anti-starvation configuration. Each severity has a time budget; when a
/// waiting complaint exceeds it, the background worker bumps its severity one
/// step, flags it overdue, and restarts the timer. Higher severity ⇒ shorter
/// budget ⇒ more frequent alerts. Values are configured under "Escalation" in
/// appsettings; the dev defaults are deliberately short so the behaviour is
/// visible during a demo — raise them for production.
/// </summary>
public class EscalationOptions
{
    public Dictionary<TicketPriority, int> ThresholdMinutes { get; set; } = new()
    {
        [TicketPriority.Low] = 10,
        [TicketPriority.Medium] = 6,
        [TicketPriority.Urgent] = 3,
        [TicketPriority.Critical] = 3,
    };

    public int CheckIntervalSeconds { get; set; } = 30;

    public TimeSpan ThresholdFor(TicketPriority severity) =>
        TimeSpan.FromMinutes(ThresholdMinutes.TryGetValue(severity, out var m) ? m : 60);
}
