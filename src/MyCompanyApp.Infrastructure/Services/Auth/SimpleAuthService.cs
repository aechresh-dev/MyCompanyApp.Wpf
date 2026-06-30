using MyCompanyApp.Application.Interfaces.Auth;
using MyCompanyApp.Application.Models.Auth;

namespace MyCompanyApp.Infrastructure.Services.Auth;

[Obsolete("SimpleAuthService is deprecated. Use AuthService instead.")]
public sealed class SimpleAuthService : IAuthService
{
    public Task<LoginResult> LoginAsync(string username, string password)
    {
        return Task.FromResult(new LoginResult
        {
            Success = false,
            Message = "SimpleAuthService is deprecated."
        });
    }
}
