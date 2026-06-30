using Microsoft.Extensions.DependencyInjection;
using MyCompanyApp.Application.Behaviors;

namespace MyCompanyApp.Application.DependencyInjection;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddApplicationLayer(this IServiceCollection services)
    {
        services.AddScoped<LoggingBehavior>();
        return services;
    }
}
