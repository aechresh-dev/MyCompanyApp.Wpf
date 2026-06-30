using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using MyCompanyApp.Persistence;

namespace MyCompanyApp.Wpf.Startup;

public static class DependencyInjectionExtensions
{
    public static IServiceCollection AddWpfServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString("DefaultConnection");

        services.AddPersistence(connectionString!);

        return services;
    }
}
