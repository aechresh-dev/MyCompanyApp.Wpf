namespace MyCompanyApp.Domain.Entities.Security;

public class RolePermission
{
    public Guid RoleId { get; set; }

    public Guid PermissionId { get; set; }
}
