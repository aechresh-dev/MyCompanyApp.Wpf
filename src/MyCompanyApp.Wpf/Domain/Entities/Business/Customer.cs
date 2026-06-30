using MyCompanyApp.Domain.Entities.Base;

namespace MyCompanyApp.Domain.Entities.Business;

public class Customer : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string Phone { get; set; } = string.Empty;
}
