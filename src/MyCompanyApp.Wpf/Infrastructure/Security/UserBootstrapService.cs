using Microsoft.EntityFrameworkCore;
using MyCompanyApp.Application.Contracts.Security;
using MyCompanyApp.Domain.Entities.Identity;
using MyCompanyApp.Infrastructure.Persistence;

namespace MyCompanyApp.Infrastructure.Security;

public class UserBootstrapService : IUserBootstrapService
{
    private readonly AppDbContext _db;
    private readonly IPasswordHasher _passwordHasher;

    public UserBootstrapService(AppDbContext db, IPasswordHasher passwordHasher)
    {
        _db = db;
        _passwordHasher = passwordHasher;
    }

    public Task<bool> HasAnyUserAsync(CancellationToken cancellationToken = default)
    {
        return _db.Users.AnyAsync(cancellationToken);
    }

    public async Task CreateFirstAdminAsync(string username, string password, string fullName, CancellationToken cancellationToken = default)
    {
        if (await _db.Users.AnyAsync(cancellationToken))
            throw new InvalidOperationException("Bootstrap is only allowed when no users exist.");

        var adminRole = await _db.Roles.FirstAsync(r => r.Name == "ADMIN", cancellationToken);

        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = username.Trim(),
            PasswordHash = _passwordHasher.Hash(password),
            FullName = fullName.Trim(),
            IsActive = true
        };

        _db.Users.Add(user);
        await _db.SaveChangesAsync(cancellationToken);

        _db.UserRoles.Add(new UserRole
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            RoleId = adminRole.Id
        });

        await _db.SaveChangesAsync(cancellationToken);
    }
}
