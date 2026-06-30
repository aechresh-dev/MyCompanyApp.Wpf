using Microsoft.Extensions.DependencyInjection;
using MyCompanyApp.Platform.UI.Navigation;
using MyCompanyApp.Modules.Users.Views;

namespace MyCompanyApp.Modules.Users;

public static class UsersModule
{
    public static void Register(IServiceCollection services, NavigationRouteRegistry registry)
    {
        services.AddTransient<UsersView>();
        registry.Register<UsersView>("users");
    }
}
