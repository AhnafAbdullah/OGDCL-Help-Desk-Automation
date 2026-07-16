using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Ogdcl.Application.Auth;
using Ogdcl.Application.Common;
using Ogdcl.Application.Files;
using Ogdcl.Application.Notifications;
using Ogdcl.Application.Tickets;
using Ogdcl.Application.Visits;
using Ogdcl.Infrastructure.Auth;
using Ogdcl.Infrastructure.Escalation;
using Ogdcl.Infrastructure.Files;
using Ogdcl.Infrastructure.Otp;
using Ogdcl.Infrastructure.Persistence;

namespace Ogdcl.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration config)
    {
        // Database provider is a config switch: SQLite for development,
        // SQL Server for OGDCL deployment ("Database:Provider": "SqlServer").
        var dbProvider = config["Database:Provider"] ?? "Sqlite";
        var connectionString = config.GetConnectionString("Default") ?? "Data Source=ogdcl_dev.db";
        services.AddDbContext<AppDbContext>(options =>
        {
            if (dbProvider.Equals("SqlServer", StringComparison.OrdinalIgnoreCase))
                options.UseSqlServer(connectionString);
            else
                options.UseSqlite(connectionString);
        });
        services.AddScoped<IAppDbContext>(sp => sp.GetRequiredService<AppDbContext>());

        var jwtOptions = new JwtOptions();
        config.GetSection("Jwt").Bind(jwtOptions);
        services.AddSingleton(jwtOptions);
        services.AddSingleton<IJwtTokenService, JwtTokenService>();
        services.AddSingleton<IPasswordHasher, Pbkdf2PasswordHasher>();

        // Auth provider is a config switch: "Dev" (seeded store) or "Ldap" (OGDCL AD).
        var authProvider = config["Auth:Provider"] ?? "Dev";
        if (authProvider.Equals("Ldap", StringComparison.OrdinalIgnoreCase))
            services.AddScoped<IAuthProvider, LdapAuthProvider>();
        else
            services.AddScoped<IAuthProvider, DevAuthProvider>();

        services.AddSingleton(TimeProvider.System);
        services.AddSingleton<IOtpStore, InMemoryOtpStore>();
        services.AddSingleton(new OtpOptions(
            TimeSpan.FromHours(config.GetValue("Otp:TtlHours", 24)),
            config.GetValue("Otp:MaxAttempts", 5)));

        // Anti-starvation escalation thresholds (per severity, in minutes).
        var escalation = new EscalationOptions();
        config.GetSection("Escalation").Bind(escalation);
        services.AddSingleton(escalation);
        services.AddHostedService<EscalationWorker>();

        services.AddSingleton<IFileStorage>(_ => new LocalFileStorage(config["Storage:Root"] ?? "storage"));

        services.AddScoped<AuthService>(sp => new AuthService(
            sp.GetRequiredService<IAppDbContext>(),
            sp.GetRequiredService<IAuthProvider>(),
            sp.GetRequiredService<IJwtTokenService>(),
            sp.GetRequiredService<JwtOptions>().RefreshTokenDays));
        services.AddScoped<TicketService>();
        services.AddScoped<VisitService>();
        services.AddScoped<NotificationService>();
        services.AddScoped<INotifier>(sp => sp.GetRequiredService<NotificationService>());

        return services;
    }
}
