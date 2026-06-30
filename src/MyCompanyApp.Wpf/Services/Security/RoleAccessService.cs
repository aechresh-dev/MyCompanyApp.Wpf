namespace MyCompanyApp.Wpf.Services.Security;

public sealed class RoleAccessService : IRoleAccessService
{
    private readonly IUserContext _userContext;

    private static readonly Dictionary<string, HashSet<string>> PermissionsByRole =
        new(StringComparer.OrdinalIgnoreCase)
        {
            ["Admin"] =
            [
                "Dashboard.View",
                "Users.View",
                "Users.Manage",
                "Leave.View",
                "Leave.Approve",
                "System.Health"
            ],

            ["Manager"] =
            [
                "Dashboard.View",
                "Users.View",
                "Leave.View",
                "Leave.Approve"
            ],

            ["Employee"] =
            [
                "Dashboard.View",
                "Leave.View"
            ]
        };

    public RoleAccessService(IUserContext userContext)
    {
        _userContext = userContext;
    }

    public bool HasPermission(string permission)
    {
        var role = _userContext.CurrentUser?.Role;

        if (string.IsNullOrWhiteSpace(role))
            return false;

        return HasPermission(role, permission);
    }

    public bool HasPermission(string role, string permission)
    {
        if (string.IsNullOrWhiteSpace(role) || string.IsNullOrWhiteSpace(permission))
            return false;

        return PermissionsByRole.TryGetValue(role, out var permissions)
               && permissions.Contains(permission);
    }
}