namespace MyCompanyApp.Wpf.Services.Security;

public sealed class UserContext : IUserContext
{
    public CurrentUser? CurrentUser { get; private set; }

    public bool IsAuthenticated => CurrentUser?.IsAuthenticated == true;

    public void SignIn(string userName, string displayName, string role)
    {
        CurrentUser = new CurrentUser
        {
            UserName = userName,
            DisplayName = displayName,
            Role = role,
            IsAuthenticated = true
        };
    }

    public void SignOut()
    {
        CurrentUser = null;
    }
}