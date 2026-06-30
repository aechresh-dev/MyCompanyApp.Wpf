namespace MyCompanyApp.Wpf.Services.Security;

public interface IUserContext
{
    CurrentUser? CurrentUser { get; }

    bool IsAuthenticated { get; }

    void SignIn(string userName, string displayName, string role);

    void SignOut();
}