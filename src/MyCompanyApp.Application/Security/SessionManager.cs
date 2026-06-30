namespace MyCompanyApp.Application.Security;

public sealed class SessionManager
{
    public string Username { get; private set; } = string.Empty;
    public string Role { get; private set; } = string.Empty;

    public bool IsAuthenticated => !string.IsNullOrWhiteSpace(Username);

    public void Start(string username, string role)
    {
        Username = username;
        Role = role;
    }

    public void End()
    {
        Username = string.Empty;
        Role = string.Empty;
    }
}
