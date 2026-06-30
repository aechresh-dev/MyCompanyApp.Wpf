using Microsoft.Extensions.Logging;

namespace MyCompanyApp.Application.Behaviors;

public sealed class LoggingBehavior
{
    private readonly ILogger<LoggingBehavior> _logger;

    public LoggingBehavior(ILogger<LoggingBehavior> logger)
    {
        _logger = logger;
    }

    public void Log(string message)
    {
        _logger.LogInformation("[APP LOG] {Message}", message);
    }
}
