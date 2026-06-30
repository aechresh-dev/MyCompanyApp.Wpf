using System.Collections.Generic;
using System.Linq;
using MyCompanyApp.Application.Interfaces.Security;
using MyCompanyApp.Application.Modules;
using MyCompanyApp.Domain.Entities.Security;

namespace MyCompanyApp.Infrastructure.Modules;

public sealed class PermissionAwareModuleCatalog : IModuleCatalog
{
    private readonly IAuthorizationService _authorization;

    private static readonly IReadOnlyList<AppModuleDescriptor> Modules = new List<AppModuleDescriptor>
    {
        new()
        {
            Id = "dashboard",
            DisplayName = "ط¯ط§ط´ط¨ظˆط±ط¯",
            Description = "ظ†ظ…ط§غŒ ع©ظ„غŒ ط³غŒط³طھظ… ظˆ ط´ط§ط®طµâ€Œظ‡ط§غŒ ط§طµظ„غŒ",
            Icon = "Dashboard",
            RequiredPermission = PermissionKeys.Dashboard_View,
            SortOrder = 10
        },
        new()
        {
            Id = "users",
            DisplayName = "ع©ط§ط±ط¨ط±ط§ظ†",
            Description = "ظ…ط¯غŒط±غŒطھ ع©ط§ط±ط¨ط±ط§ظ†طŒ ظ†ظ‚ط´â€Œظ‡ط§ ظˆ ط¯ط³طھط±ط³غŒâ€Œظ‡ط§",
            Icon = "Users",
            RequiredPermission = PermissionKeys.Users_View,
            SortOrder = 20
        },
        new()
        {
            Id = "leave",
            DisplayName = "ظ…ط±ط®طµغŒâ€Œظ‡ط§",
            Description = "ط«ط¨طھ ظˆ ط¨ط±ط±ط³غŒ ط¯ط±ط®ظˆط§ط³طھâ€Œظ‡ط§غŒ ظ…ط±ط®طµغŒ",
            Icon = "Calendar",
            RequiredPermission = PermissionKeys.Leave_View,
            SortOrder = 30
        },
        new()
        {
            Id = "reports",
            DisplayName = "ع¯ط²ط§ط±ط´â€Œظ‡ط§",
            Description = "ع¯ط²ط§ط±ط´â€Œظ‡ط§غŒ ظ…ط¯غŒط±غŒطھغŒ ظˆ ط¹ظ…ظ„غŒط§طھغŒ",
            Icon = "Reports",
            RequiredPermission = PermissionKeys.Reports_View,
            SortOrder = 40
        }
    };

    public PermissionAwareModuleCatalog(IAuthorizationService authorization)
    {
        _authorization = authorization;
    }

    public IReadOnlyList<AppModuleDescriptor> GetAvailableModules()
    {
        return Modules
            .Where(module =>
                string.IsNullOrWhiteSpace(module.RequiredPermission) ||
                _authorization.HasPermission(module.RequiredPermission))
            .OrderBy(module => module.SortOrder)
            .ToList();
    }

    public IReadOnlyList<AppModuleDescriptor> GetAllModules()
    {
        return Modules
            .OrderBy(module => module.SortOrder)
            .ToList();
    }
}


