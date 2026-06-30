using Microsoft.Extensions.DependencyInjection;
using MyCompanyApp.Modules.Users.Services;

namespace MyCompanyApp.Modules.Users.DependencyInjection;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddUsersModule(this IServiceCollection services)
    {
        services.AddScoped<IUserService, UserService>();

        return services;
    }
}
