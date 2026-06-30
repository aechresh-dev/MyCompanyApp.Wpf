using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MyCompanyApp.Application.Contracts.Security;
using MyCompanyApp.Application.Services.Security;
using MyCompanyApp.Infrastructure.Persistence;
using MyCompanyApp.Infrastructure.Security;

namespace MyCompanyApp.Presentation.Bootstrap;

public static class AppBootstrapper
{
    public static IServiceProvider Build()
    {
        var services = new ServiceCollection();

        services.AddDbContext<AppDbContext>(options =>
            options.UseSqlite("Data Source=app.db"));

        services.AddScoped<IPasswordHasher, BCryptPasswordHasher>();
        services.AddScoped<IUserBootstrapService, UserBootstrapService>();

        return services.BuildServiceProvider();
    }
}
