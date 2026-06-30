namespace MyCompanyApp.Application.Modules;

public sealed class AppModuleDescriptor
{
    public string Id { get; init; } = string.Empty;

    public string DisplayName { get; init; } = string.Empty;

    public string? Description { get; init; }

    public string? Icon { get; init; }

    public string? RequiredPermission { get; init; }

    public int SortOrder { get; init; }
}
