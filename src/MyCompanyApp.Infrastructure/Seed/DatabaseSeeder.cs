using Microsoft.EntityFrameworkCore;
using MyCompanyApp.Domain.Entities;
using MyCompanyApp.Infrastructure.Security;
using MyCompanyApp.Persistence.Database;

namespace MyCompanyApp.Infrastructure.Seed;

public static class DatabaseSeeder
{
    public static async Task SeedAsync(MyCompanyDbContext db)
    {
        if(await db.Users.AnyAsync())
            return;

        var role=new Role
        {
            Id=Guid.NewGuid(),
            Name="SuperAdmin"
        };

        var user=new User
        {
            Id=Guid.NewGuid(),
            Username="admin",
            PasswordHash=PasswordHasher.HashPassword("admin123")
        };

        db.Roles.Add(role);

        db.Users.Add(user);

        db.UserRoles.Add(new UserRole
        {
            RoleId=role.Id,
            UserId=user.Id
        });

        await db.SaveChangesAsync();
    }
}
