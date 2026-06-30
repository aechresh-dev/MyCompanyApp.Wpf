namespace MyCompanyApp.Domain.Entities;

public class Role : AuditableEntity
{
    public string Name { get; set; } = "";

    public ICollection<UserRole> UserRoles { get; set; } = new List<UserRole>();
    public ICollection<RolePermission> RolePermissions { get; set; } = new List<RolePermission>();
}
