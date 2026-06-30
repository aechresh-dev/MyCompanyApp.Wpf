using Microsoft.Extensions.DependencyInjection;

namespace MyCompanyApp.Application.Abstractions
{
    public interface IModule
    {
        void RegisterServices(IServiceCollection services);
        void RegisterRoutes(IServiceCollection services);
    }
}
