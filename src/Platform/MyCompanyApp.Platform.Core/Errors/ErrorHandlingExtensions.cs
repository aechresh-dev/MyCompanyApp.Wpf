using Microsoft.Extensions.DependencyInjection;

namespace MyCompanyApp.Platform.Core.Errors;

public static class ErrorHandlingExtensions
{
    public static IServiceCollection AddErrorHandling(this IServiceCollection services)
    {
        return services;
    }
}
