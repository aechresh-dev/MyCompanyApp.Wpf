namespace MyCompanyApp.Infrastructure.Security;

public static class UserSession
{
    public static Guid? UserId { get; private set; }
    public static string? Username { get; private set; }
    public static string? Role { get; private set; }

    public static bool IsAuthenticated => UserId != null;

    public static void Create(Guid userId, string username, string role)
    {
        UserId = userId;
        Username = username;
        Role = role;
    }

    public static void Clear()
    {
        UserId = null;
        Username = null;
        Role = null;
    }
}
