using Microsoft.Extensions.DependencyInjection;

namespace MyCompanyApp.Platform.Core.Services;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddBaseServices(this IServiceCollection services)
    {
        services.AddSingleton<IClock, SystemClock>();
        services.AddScoped<ICurrentUserService, DefaultCurrentUserService>();

        return services;
    }
}
