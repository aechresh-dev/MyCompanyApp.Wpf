using Microsoft.Extensions.Logging;

namespace MyCompanyApp.Platform.Core.Services;

public abstract class ServiceBase<TService>
{
    protected ServiceBase(
        ILogger<TService> logger,
        IClock clock,
        ICurrentUserService currentUser)
    {
        Logger = logger;
        Clock = clock;
        CurrentUser = currentUser;
    }

    protected ILogger<TService> Logger { get; }
    protected IClock Clock { get; }
    protected ICurrentUserService CurrentUser { get; }
}
