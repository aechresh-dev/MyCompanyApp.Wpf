using Microsoft.Extensions.DependencyInjection;

namespace MyCompanyApp.Platform.Core.Errors;

public static class ErrorHandlingExtensions
{
    public static IServiceCollection AddErrorHandling(this IServiceCollection services)
    {
        // In the future we can add:
        // - Exception translators
        // - Logging decorators
        // - Global error reporting
        // - Telemetry
        return services;
    }
}
