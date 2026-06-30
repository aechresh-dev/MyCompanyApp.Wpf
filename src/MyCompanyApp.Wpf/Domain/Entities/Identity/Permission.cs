using MyCompanyApp.Domain.Entities.Base;

namespace MyCompanyApp.Domain.Entities.Identity;

public class Permission : BaseEntity
{
    public string Key { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string? ModuleName { get; set; }
}
