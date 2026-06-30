namespace MyCompanyApp.Wpf.Services.Security;

public interface IRoleAccessService
{
    bool HasPermission(string permission);

    bool HasPermission(string role, string permission);
}