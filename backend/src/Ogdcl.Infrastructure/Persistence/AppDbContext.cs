using Microsoft.EntityFrameworkCore;
using Ogdcl.Application.Common;
using Ogdcl.Domain.Entities;

namespace Ogdcl.Infrastructure.Persistence;

public class AppDbContext : DbContext, IAppDbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<User> Users => Set<User>();
    public DbSet<Department> Departments => Set<Department>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<ComplaintCategory> ComplaintCategories => Set<ComplaintCategory>();
    public DbSet<AssignmentRule> AssignmentRules => Set<AssignmentRule>();
    public DbSet<Ticket> Tickets => Set<Ticket>();
    public DbSet<TicketAttachment> TicketAttachments => Set<TicketAttachment>();
    public DbSet<TicketStatusHistory> TicketStatusHistory => Set<TicketStatusHistory>();
    public DbSet<TicketRejection> TicketRejections => Set<TicketRejection>();
    public DbSet<TicketFeedback> TicketFeedback => Set<TicketFeedback>();
    public DbSet<Visitor> Visitors => Set<Visitor>();
    public DbSet<VisitRequest> VisitRequests => Set<VisitRequest>();
    public DbSet<Zone> Zones => Set<Zone>();
    public DbSet<VisitZonePermission> VisitZonePermissions => Set<VisitZonePermission>();
    public DbSet<RfidCard> RfidCards => Set<RfidCard>();
    public DbSet<Notification> Notifications => Set<Notification>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<User>(e =>
        {
            e.HasIndex(x => x.Username).IsUnique();
            e.Property(x => x.Username).HasMaxLength(100);
            e.Property(x => x.DisplayName).HasMaxLength(200);
        });

        modelBuilder.Entity<RefreshToken>(e =>
        {
            e.HasIndex(x => x.Token).IsUnique();
        });

        modelBuilder.Entity<AssignmentRule>(e =>
        {
            // one routing rule per category
            e.HasIndex(x => x.CategoryId).IsUnique();
        });

        modelBuilder.Entity<Ticket>(e =>
        {
            e.HasIndex(x => x.TicketNumber).IsUnique();
            e.HasIndex(x => x.Status);
            e.HasOne(x => x.CreatedBy).WithMany().HasForeignKey(x => x.CreatedById).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.AssignedTo).WithMany().HasForeignKey(x => x.AssignedToId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Department).WithMany().HasForeignKey(x => x.DepartmentId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Feedback).WithOne(f => f.Ticket).HasForeignKey<TicketFeedback>(f => f.TicketId);
            e.HasQueryFilter(x => !x.IsDeleted);
        });

        modelBuilder.Entity<TicketStatusHistory>(e =>
        {
            // ChangedById is nullable: system actions (auto-escalation) have no user.
            e.HasOne(x => x.ChangedBy).WithMany().HasForeignKey(x => x.ChangedById).OnDelete(DeleteBehavior.Restrict);
            e.HasQueryFilter(x => !x.Ticket.IsDeleted);
        });

        modelBuilder.Entity<TicketRejection>(e =>
        {
            e.HasIndex(x => new { x.TicketId, x.HandlerId }).IsUnique();
            e.HasOne(x => x.Ticket).WithMany(t => t.Rejections).HasForeignKey(x => x.TicketId);
            e.HasOne(x => x.Handler).WithMany().HasForeignKey(x => x.HandlerId).OnDelete(DeleteBehavior.Restrict);
            e.HasQueryFilter(x => !x.Ticket.IsDeleted);
        });

        modelBuilder.Entity<TicketAttachment>(e =>
        {
            e.HasQueryFilter(x => !x.Ticket.IsDeleted);
        });

        modelBuilder.Entity<TicketFeedback>(e =>
        {
            e.HasQueryFilter(x => !x.Ticket.IsDeleted);
        });

        modelBuilder.Entity<Visitor>(e =>
        {
            e.HasIndex(x => x.Cnic).IsUnique();
            e.Property(x => x.Cnic).HasMaxLength(20);
        });

        modelBuilder.Entity<VisitRequest>(e =>
        {
            e.HasIndex(x => x.Status);
            e.HasOne(x => x.Host).WithMany().HasForeignKey(x => x.HostId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Visitor).WithMany(v => v.Visits).HasForeignKey(x => x.VisitorId);
            e.HasOne(x => x.Card).WithMany().HasForeignKey(x => x.CardId).OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<VisitZonePermission>(e =>
        {
            e.HasKey(x => new { x.VisitRequestId, x.ZoneId });
        });

        modelBuilder.Entity<RfidCard>(e =>
        {
            e.HasIndex(x => x.CardUid).IsUnique();
        });

        modelBuilder.Entity<Notification>(e =>
        {
            e.HasIndex(x => new { x.UserId, x.ReadAt });
        });
    }
}
