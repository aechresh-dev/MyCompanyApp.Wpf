using Microsoft.Extensions.DependencyInjection;
using MyCompanyApp.Wpf.Core.Navigation;
using MyCompanyApp.Wpf.Views;

namespace MyCompanyApp.Wpf.Startup;

public static class WpfShellServiceCollectionExtensions
{
    public static IServiceCollection AddWpfShellServices(this IServiceCollection services)
    {
        services.AddSingleton<NavigationService>();
        services.AddSingleton<AppShell>();

        services.AddTransient<DashboardView>();
        services.AddTransient<UsersView>();
        services.AddTransient<LeaveView>();

        return services;
    }
}