using Microsoft.Extensions.DependencyInjection;
using MyCompanyApp.Wpf.Core.Navigation;

namespace MyCompanyApp.Wpf.Startup
{
    public static class ServiceCollectionExtensions
    {
        public static void AddApplicationServices(this IServiceCollection services)
        {
            services.AddSingleton<NavigationService>();

            services.AddSingleton<AppShell>();
        }
    }
}
