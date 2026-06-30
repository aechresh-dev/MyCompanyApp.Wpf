namespace MyCompanyApp.Application.Interfaces.Security;

public interface IAuthorizationService
{
    bool HasPermission(string permission);

    bool HasAnyPermission(params string[] permissions);
}
