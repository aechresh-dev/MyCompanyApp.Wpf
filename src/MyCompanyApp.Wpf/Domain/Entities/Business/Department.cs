using MyCompanyApp.Domain.Entities.Base;

namespace MyCompanyApp.Domain.Entities.Business;

public class Department : BaseEntity
{
    public string Name { get; set; } = string.Empty;
}
