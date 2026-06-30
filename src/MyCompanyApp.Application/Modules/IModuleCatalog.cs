using System.Collections.Generic;

namespace MyCompanyApp.Application.Modules;

public interface IModuleCatalog
{
    IReadOnlyList<AppModuleDescriptor> GetAvailableModules();

    IReadOnlyList<AppModuleDescriptor> GetAllModules();
}
