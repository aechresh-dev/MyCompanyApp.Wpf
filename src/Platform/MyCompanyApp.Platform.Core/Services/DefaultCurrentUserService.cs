namespace MyCompanyApp.Platform.Core.Services;

public sealed class DefaultCurrentUserService : ICurrentUserService
{
    public string? UserId => null;
    public string? UserName => null;
    public bool IsAuthenticated => false;
}
