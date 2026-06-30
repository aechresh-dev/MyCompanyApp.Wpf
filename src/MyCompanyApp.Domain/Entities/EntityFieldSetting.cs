using System;

namespace MyCompanyApp.Domain.Entities;

public class EntityFieldSetting
{
    public long Id { get; set; }
    public string EntityName { get; set; } = string.Empty;
    public string FieldName { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string FieldType { get; set; } = string.Empty;
    public bool IsEnabled { get; set; } = true;
    public bool IsRequired { get; set; }
    public bool IsVisibleInForm { get; set; } = true;
    public bool IsVisibleInGrid { get; set; } = true;
    public bool IsVisibleInReport { get; set; } = true;
    public int DisplayOrder { get; set; }
    public string? DefaultValue { get; set; }
    public string? Description { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }
}
