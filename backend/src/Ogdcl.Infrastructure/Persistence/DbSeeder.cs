using Microsoft.EntityFrameworkCore;
using Ogdcl.Application.Auth;
using Ogdcl.Domain;
using Ogdcl.Domain.Entities;

namespace Ogdcl.Infrastructure.Persistence;

/// <summary>
/// Seeds dummy development data: departments, complaint categories with routing
/// rules, zones, and demo accounts. Real employee data is only entered at
/// deployment, per the proposal's data-gathering commitment.
/// </summary>
public static class DbSeeder
{
    public static async Task SeedAsync(AppDbContext db, IPasswordHasher hasher)
    {
        if (await db.Users.AnyAsync())
            return;

        var it = new Department { Name = "IT" };
        var maintenance = new Department { Name = "Maintenance" };
        var hr = new Department { Name = "HR" };
        var facilities = new Department { Name = "Facilities" };
        var civil = new Department { Name = "Civil Works" };
        db.Departments.AddRange(it, maintenance, hr, facilities, civil);

        var catIt = new ComplaintCategory { Name = "IT Support" };
        var catMaintenance = new ComplaintCategory { Name = "Maintenance" };
        var catHr = new ComplaintCategory { Name = "HR" };
        var catFacilities = new ComplaintCategory { Name = "Facilities" };
        var catCivil = new ComplaintCategory { Name = "Civil Works" };
        db.ComplaintCategories.AddRange(catIt, catMaintenance, catHr, catFacilities, catCivil);

        // Routing only maps category → department; severity is chosen by the employee.
        db.AssignmentRules.AddRange(
            new AssignmentRule { Category = catIt, Department = it, DefaultPriority = TicketPriority.Medium },
            new AssignmentRule { Category = catMaintenance, Department = maintenance, DefaultPriority = TicketPriority.Medium },
            new AssignmentRule { Category = catHr, Department = hr, DefaultPriority = TicketPriority.Low },
            new AssignmentRule { Category = catFacilities, Department = facilities, DefaultPriority = TicketPriority.Medium },
            new AssignmentRule { Category = catCivil, Department = civil, DefaultPriority = TicketPriority.Medium });

        db.Zones.AddRange(
            new Zone { Name = "Main Lobby" },
            new Zone { Name = "Conference Rooms" },
            new Zone { Name = "IT Wing" },
            new Zone { Name = "Finance Wing", IsRestricted = true },
            new Zone { Name = "Server Room", IsRestricted = true });

        User MakeUser(string username, string password, string displayName, UserRole role, Department? dept, string email = "") =>
            new()
            {
                Username = username,
                DisplayName = displayName,
                Email = string.IsNullOrEmpty(email) ? $"{username}@ogdcl.dev" : email,
                Role = role,
                Department = dept,
                PasswordHash = hasher.Hash(password),
            };

        db.Users.AddRange(
            // Super admin — full oversight, global settings. Cannot raise complaints.
            MakeUser("admin", "Admin@123", "System Administrator", UserRole.SuperAdmin, null),

            // Floor admins — one per department; approve urgent complaints and
            // monitor that department's handlers.
            MakeUser("it.admin", "Floor@123", "Kamran Ali (IT Floor Admin)", UserRole.FloorAdmin, it),
            MakeUser("hr.admin", "Floor@123", "Nadia Farooq (HR Floor Admin)", UserRole.FloorAdmin, hr),
            MakeUser("fac.admin", "Floor@123", "Zeeshan Haider (Facilities Floor Admin)", UserRole.FloorAdmin, facilities),
            MakeUser("maint.admin", "Floor@123", "Waleed Iqbal (Maintenance Floor Admin)", UserRole.FloorAdmin, maintenance),
            MakeUser("civil.admin", "Floor@123", "Hamza Sheikh (Civil Floor Admin)", UserRole.FloorAdmin, civil),

            // Employees — raise complaints.
            MakeUser("ayan", "Employee@123", "Muhammad Ayan", UserRole.Employee, it),
            MakeUser("umer", "Employee@123", "Muhammad Umer", UserRole.Employee, hr),
            MakeUser("ibrahim", "Employee@123", "Ibrahim Ahmad", UserRole.Employee, facilities),

            // Handlers — accept and resolve complaints.
            MakeUser("it.handler1", "Handler@123", "Bilal Khan (IT Support)", UserRole.Handler, it),
            MakeUser("it.handler2", "Handler@123", "Sana Tariq (IT Support)", UserRole.Handler, it),
            MakeUser("maint.handler1", "Handler@123", "Rashid Mehmood (Maintenance)", UserRole.Handler, maintenance),
            MakeUser("hr.handler1", "Handler@123", "Ayesha Noor (HR)", UserRole.Handler, hr),
            MakeUser("fac.handler1", "Handler@123", "Imran Shah (Facilities)", UserRole.Handler, facilities),
            MakeUser("civil.handler1", "Handler@123", "Tariq Aziz (Civil Works)", UserRole.Handler, civil),

            // Security / gate staff.
            MakeUser("guard1", "Guard@123", "Gate Guard One", UserRole.Security, null),
            MakeUser("guard2", "Guard@123", "Gate Guard Two", UserRole.Security, null));

        await db.SaveChangesAsync();
    }
}
