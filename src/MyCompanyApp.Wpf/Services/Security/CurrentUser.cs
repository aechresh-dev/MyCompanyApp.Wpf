namespace MyCompanyApp.Wpf.Services.Security;

public sealed class CurrentUser
{
    public string UserName { get; init; } = string.Empty;

    public string DisplayName { get; init; } = string.Empty;

    public string Role { get; init; } = "Employee";

    public bool IsAuthenticated { get; init; }
}