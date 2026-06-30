using Microsoft.Extensions.DependencyInjection;
using MyCompanyApp.Application.Interfaces.Auth;
using MyCompanyApp.Infrastructure.Services.Auth;

namespace MyCompanyApp.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services)
    {
        services.AddScoped<IAuthService, AuthService>();

        return services;
    }
}
