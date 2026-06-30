namespace MyCompanyApp.Application.Models.Auth;

public sealed class LoginResult
{
    public bool Success { get; init; }

    public string Message { get; init; } = string.Empty;

    public string? Username { get; init; }

    public string? DisplayName { get; init; }
}
