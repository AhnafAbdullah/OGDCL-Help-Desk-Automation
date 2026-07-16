using Microsoft.EntityFrameworkCore;
using Ogdcl.Domain.Entities;

namespace Ogdcl.Application.Common;

public interface IAppDbContext
{
    DbSet<User> Users { get; }
    DbSet<Department> Departments { get; }
    DbSet<RefreshToken> RefreshTokens { get; }
    DbSet<ComplaintCategory> ComplaintCategories { get; }
    DbSet<AssignmentRule> AssignmentRules { get; }
    DbSet<Ticket> Tickets { get; }
    DbSet<TicketAttachment> TicketAttachments { get; }
    DbSet<TicketStatusHistory> TicketStatusHistory { get; }
    DbSet<TicketRejection> TicketRejections { get; }
    DbSet<TicketFeedback> TicketFeedback { get; }
    DbSet<Visitor> Visitors { get; }
    DbSet<VisitRequest> VisitRequests { get; }
    DbSet<Zone> Zones { get; }
    DbSet<VisitZonePermission> VisitZonePermissions { get; }
    DbSet<RfidCard> RfidCards { get; }
    DbSet<Notification> Notifications { get; }

    Task<int> SaveChangesAsync(CancellationToken ct = default);
}
