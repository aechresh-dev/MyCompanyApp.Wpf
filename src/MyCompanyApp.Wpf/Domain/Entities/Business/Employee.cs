using MyCompanyApp.Domain.Entities.Base;

namespace MyCompanyApp.Domain.Entities.Business;

public class Employee : BaseEntity
{
    public string FullName { get; set; } = string.Empty;
    public string Position { get; set; } = string.Empty;
}
