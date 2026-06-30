using System.Windows;
using MyCompanyApp.Application.Interfaces.Security;

namespace MyCompanyApp.Platform.UI.Security;

public class PermissionGuard
{
    private readonly IAuthorizationService _authorization;

    public PermissionGuard(IAuthorizationService authorization)
    {
        _authorization = authorization;
    }

    public void Protect(UIElement element, string permission)
    {
        if (!_authorization.HasPermission(permission))
        {
            element.Visibility = Visibility.Collapsed;
        }
    }

    public void Disable(UIElement element, string permission)
    {
        if (!_authorization.HasPermission(permission))
        {
            element.IsEnabled = false;
        }
    }
}
