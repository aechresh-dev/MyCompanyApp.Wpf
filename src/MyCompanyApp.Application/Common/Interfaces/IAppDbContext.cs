using MyCompanyApp.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace MyCompanyApp.Application.Common.Interfaces;

public interface IAppDbContext
{
    DbSet<User> Users { get; }
    DbSet<Role> Roles { get; }
    DbSet<Permission> Permissions { get; }
    DbSet<UserRole> UserRoles { get; }
    DbSet<RolePermission> RolePermissions { get; }
    
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
