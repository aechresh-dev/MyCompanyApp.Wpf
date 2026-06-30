using MyCompanyApp.Application.Models.Auth;

namespace MyCompanyApp.Application.Interfaces.Auth;

public interface IAuthService
{
    Task<LoginResult> LoginAsync(string username, string password);
}
