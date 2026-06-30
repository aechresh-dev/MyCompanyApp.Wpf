using Microsoft.EntityFrameworkCore;
using MyCompanyApp.Domain.Entities.Identity;

namespace MyCompanyApp.Infrastructure.Persistence;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<User> Users => Set<User>();
    public DbSet<Role> Roles => Set<Role>();
    public DbSet<Permission> Permissions => Set<Permission>();
    public DbSet<UserRole> UserRoles => Set<UserRole>();
    public DbSet<RolePermission> RolePermissions => Set<RolePermission>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<User>(b =>
        {
            b.HasIndex(x => x.Username).IsUnique();
            b.Property(x => x.Username).HasMaxLength(100).IsRequired();
            b.Property(x => x.PasswordHash).HasMaxLength(500).IsRequired();
            b.Property(x => x.FullName).HasMaxLength(200).IsRequired();
        });

        modelBuilder.Entity<Role>(b =>
        {
            b.HasIndex(x => x.Name).IsUnique();
            b.Property(x => x.Name).HasMaxLength(50).IsRequired();
            b.Property(x => x.Description).HasMaxLength(250);
        });

        modelBuilder.Entity<Permission>(b =>
        {
            b.HasIndex(x => x.Key).IsUnique();
            b.Property(x => x.Key).HasMaxLength(150).IsRequired();
            b.Property(x => x.DisplayName).HasMaxLength(200).IsRequired();
            b.Property(x => x.ModuleName).HasMaxLength(100);
        });

        modelBuilder.Entity<UserRole>(b =>
        {
            b.HasIndex(x => new { x.UserId, x.RoleId }).IsUnique();
            b.HasOne(x => x.User).WithMany(x => x.UserRoles).HasForeignKey(x => x.UserId);
            b.HasOne(x => x.Role).WithMany(x => x.UserRoles).HasForeignKey(x => x.RoleId);
        });

        modelBuilder.Entity<RolePermission>(b =>
        {
            b.HasIndex(x => new { x.RoleId, x.PermissionId }).IsUnique();
            b.HasOne(x => x.Role).WithMany(x => x.RolePermissions).HasForeignKey(x => x.RoleId);
            b.HasOne(x => x.Permission).WithMany().HasForeignKey(x => x.PermissionId);
        });

        modelBuilder.Entity<Role>().HasData(
            new Role { Id = Guid.Parse("11111111-1111-1111-1111-111111111111"), Name = "ADMIN", Description = "Full system access" },
            new Role { Id = Guid.Parse("22222222-2222-2222-2222-222222222222"), Name = "MANAGER", Description = "Operational management" },
            new Role { Id = Guid.Parse("33333333-3333-3333-3333-333333333333"), Name = "OPERATOR", Description = "Daily operations" },
            new Role { Id = Guid.Parse("44444444-4444-4444-4444-444444444444"), Name = "VIEWER", Description = "Read only access" }
        );

        modelBuilder.Entity<Permission>().HasData(
            new Permission { Id = Guid.Parse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"), Key = "system.bootstrap", DisplayName = "Bootstrap system", ModuleName = "Identity" },
            new Permission { Id = Guid.Parse("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"), Key = "users.manage", DisplayName = "Manage users", ModuleName = "Identity" },
            new Permission { Id = Guid.Parse("cccccccc-cccc-cccc-cccc-cccccccccccc"), Key = "roles.manage", DisplayName = "Manage roles", ModuleName = "Identity" },
            new Permission { Id = Guid.Parse("dddddddd-dddd-dddd-dddd-dddddddddddd"), Key = "permissions.manage", DisplayName = "Manage permissions", ModuleName = "Identity" }
        );
    }
}
