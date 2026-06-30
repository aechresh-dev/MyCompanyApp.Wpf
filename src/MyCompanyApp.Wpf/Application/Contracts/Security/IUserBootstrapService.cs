namespace MyCompanyApp.Application.Contracts.Security;

public interface IUserBootstrapService
{
    Task<bool> HasAnyUserAsync(CancellationToken cancellationToken = default);
    Task CreateFirstAdminAsync(string username, string password, string fullName, CancellationToken cancellationToken = default);
}
