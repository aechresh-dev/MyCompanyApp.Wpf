using System;
using System.Collections.Generic;
using System.Windows.Controls;
using Microsoft.Extensions.DependencyInjection;

namespace MyCompanyApp.Platform.UI.Navigation;

public sealed class NavigationRouteRegistry
{
    private readonly Dictionary<string, Type> _routes = new(StringComparer.OrdinalIgnoreCase);

    public void Register<TView>(string route) where TView : UserControl
    {
        if (string.IsNullOrWhiteSpace(route))
            throw new ArgumentException("Route cannot be null or whitespace.", nameof(route));

        _routes[route] = typeof(TView);
    }

    public Type Resolve(string route)
    {
        if (!_routes.TryGetValue(route, out var viewType))
            throw new InvalidOperationException($"Navigation route '{route}' is not registered.");

        return viewType;
    }

    public IReadOnlyCollection<string> GetAllRoutes() => _routes.Keys;
}
