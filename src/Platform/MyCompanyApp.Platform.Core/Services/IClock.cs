namespace MyCompanyApp.Platform.Core.Services;

public interface IClock
{
    DateTime Now { get; }
    DateTime UtcNow { get; }
}
