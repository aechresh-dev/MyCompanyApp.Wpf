using System;
using System.Linq;
using System.Reflection;
using System.Collections.Generic;

namespace MyCompanyApp.Application.Abstractions
{
    public static class ModuleDiscovery
    {
        public static IReadOnlyList<IModule> DiscoverModules(params Assembly[] assemblies)
        {
            var modules = new List<IModule>();

            foreach (var assembly in assemblies)
            {
                if (assembly.IsDynamic) continue;

                var types = assembly.GetTypes()
                    .Where(t =>
                        typeof(IModule).IsAssignableFrom(t) &&
                        !t.IsInterface &&
                        !t.IsAbstract);

                foreach (var type in types)
                {
                    if (Activator.CreateInstance(type) is IModule module)
                        modules.Add(module);
                }
            }

            return modules;
        }
    }
}
