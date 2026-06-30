using Microsoft.Extensions.DependencyInjection;
using MyCompanyApp.Platform.UI.Navigation;
using MyCompanyApp.Modules.Dashboard.Views;

namespace MyCompanyApp.Modules.Dashboard;

public static class DashboardModule
{
    public static void Register(IServiceCollection services, NavigationRouteRegistry registry)
    {
        services.AddTransient<DashboardView>();
        registry.Register<DashboardView>("dashboard");
    }
}
