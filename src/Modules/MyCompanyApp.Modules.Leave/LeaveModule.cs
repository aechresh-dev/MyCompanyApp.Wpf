using Microsoft.Extensions.DependencyInjection;
using MyCompanyApp.Platform.UI.Navigation;
using MyCompanyApp.Modules.Leave.Views;

namespace MyCompanyApp.Modules.Leave;

public static class LeaveModule
{
    public static void Register(IServiceCollection services, NavigationRouteRegistry registry)
    {
        services.AddTransient<LeaveView>();
        registry.Register<LeaveView>("leave");
    }
}
