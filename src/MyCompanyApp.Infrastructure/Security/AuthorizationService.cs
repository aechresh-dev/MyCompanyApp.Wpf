using MyCompanyApp.Application.Interfaces.Security;
using MyCompanyApp.Domain.Entities.Security;

namespace MyCompanyApp.Infrastructure.Security;

public class AuthorizationService : IAuthorizationService
{
    private readonly HashSet<string> _permissions = new();

    public AuthorizationService()
    {
        // TEMP Seed for Admin
        _permissions.Add(PermissionKeys.Dashboard_View);
        _permissions.Add(PermissionKeys.Users_View);
        _permissions.Add(PermissionKeys.Users_Create);
        _permissions.Add(PermissionKeys.Users_Edit);
        _permissions.Add(PermissionKeys.Users_Delete);
        _permissions.Add(PermissionKeys.Leave_View);
        _permissions.Add(PermissionKeys.Leave_Approve);
        _permissions.Add(PermissionKeys.Reports_View);
    }

    public bool HasPermission(string permission)
    {
        return _permissions.Contains(permission);
    }

    public bool HasAnyPermission(params string[] permissions)
    {
        return permissions.Any(p => _permissions.Contains(p));
    }
}



