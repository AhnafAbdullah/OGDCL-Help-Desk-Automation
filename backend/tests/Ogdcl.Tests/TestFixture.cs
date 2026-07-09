using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Ogdcl.Application.Files;
using Ogdcl.Application.Notifications;
using Ogdcl.Application.Visits;
using Ogdcl.Domain;
using Ogdcl.Domain.Entities;
using Ogdcl.Infrastructure.Otp;
using Ogdcl.Infrastructure.Persistence;

namespace Ogdcl.Tests;

/// <summary>Captures pushes instead of sending them over SignalR.</summary>
public class FakeNotificationChannel : INotificationChannel
{
    public List<(int UserId, NotificationDto Notification)> Pushed { get; } = [];

    public Task PushAsync(int userId, NotificationDto notification, CancellationToken ct = default)
    {
        Pushed.Add((userId, notification));
        return Task.CompletedTask;
    }
}

public class NullFileStorage : IFileStorage
{
    public Task<string> SaveAsync(string directory, string fileName, Stream content, CancellationToken ct = default) =>
        Task.FromResult($"{directory}/{fileName}");

    public Stream OpenRead(string storedPath) => Stream.Null;
}

public class TestTimeProvider : TimeProvider
{
    public DateTimeOffset Now { get; set; } = DateTimeOffset.UtcNow;
    public override DateTimeOffset GetUtcNow() => Now;
}

/// <summary>Records the last generated OTP so tests can verify it.</summary>
public class SpyOtpStore : IOtpStore
{
    private readonly InMemoryOtpStore _inner;

    public SpyOtpStore(TimeProvider time) => _inner = new InMemoryOtpStore(time);

    public string? LastCode { get; private set; }

    public string Generate(string key, TimeSpan ttl, int maxAttempts) =>
        LastCode = _inner.Generate(key, ttl, maxAttempts);

    public OtpVerification Verify(string key, string code) => _inner.Verify(key, code);

    public void Remove(string key) => _inner.Remove(key);
}

/// <summary>
/// A fully wired in-memory environment: SQLite in-memory database plus real
/// services with fake edges (notification channel, OTP spy, file storage).
/// </summary>
public sealed class TestFixture : IDisposable
{
    private readonly SqliteConnection _connection;

    public AppDbContext Db { get; }
    public FakeNotificationChannel Channel { get; } = new();
    public TestTimeProvider Time { get; } = new();
    public SpyOtpStore OtpStore { get; }
    public NotificationService Notifier { get; }

    // Seeded fixture data
    public Department It = null!;
    public Department Hr = null!;
    public User Employee = null!;
    public User Handler1 = null!;
    public User Handler2 = null!;
    public User HrHandler = null!;
    public User Guard = null!;
    public User Admin = null!;
    public ComplaintCategory ItCategory = null!;
    public ComplaintCategory UnroutedCategory = null!;
    public Zone Lobby = null!;
    public Zone ServerRoom = null!;

    public TestFixture()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();

        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(_connection)
            .Options;
        Db = new AppDbContext(options);
        Db.Database.EnsureCreated();

        OtpStore = new SpyOtpStore(Time);
        Notifier = new NotificationService(Db, Channel, NullLogger<NotificationService>.Instance);

        Seed();
    }

    private void Seed()
    {
        It = new Department { Name = "IT" };
        Hr = new Department { Name = "HR" };

        Employee = new User { Username = "employee", DisplayName = "Test Employee", Role = UserRole.Employee, Department = It };
        Handler1 = new User { Username = "handler1", DisplayName = "Handler One", Role = UserRole.Handler, Department = It };
        Handler2 = new User { Username = "handler2", DisplayName = "Handler Two", Role = UserRole.Handler, Department = It };
        HrHandler = new User { Username = "hrhandler", DisplayName = "HR Handler", Role = UserRole.Handler, Department = Hr };
        Guard = new User { Username = "guard", DisplayName = "Gate Guard", Role = UserRole.Security };
        Admin = new User { Username = "admin", DisplayName = "Admin", Role = UserRole.Admin };

        ItCategory = new ComplaintCategory { Name = "IT Support" };
        UnroutedCategory = new ComplaintCategory { Name = "General" };

        Lobby = new Zone { Name = "Lobby" };
        ServerRoom = new Zone { Name = "Server Room", IsRestricted = true };

        Db.AddRange(It, Hr, Employee, Handler1, Handler2, HrHandler, Guard, Admin,
            ItCategory, UnroutedCategory, Lobby, ServerRoom);
        Db.Add(new AssignmentRule { Category = ItCategory, Department = It, DefaultPriority = TicketPriority.High });
        Db.SaveChanges();
    }

    public void Dispose()
    {
        Db.Dispose();
        _connection.Dispose();
    }
}
