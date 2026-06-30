using System;
using System.Windows.Controls;
using Microsoft.Extensions.DependencyInjection;

namespace MyCompanyApp.Platform.UI.Navigation;

public sealed class NavigationService : INavigationService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly NavigationRouteRegistry _routeRegistry;
    private ContentControl? _host;

    public NavigationService(IServiceProvider serviceProvider, NavigationRouteRegistry routeRegistry)
    {
        _serviceProvider = serviceProvider ?? throw new ArgumentNullException(nameof(serviceProvider));
        _routeRegistry = routeRegistry ?? throw new ArgumentNullException(nameof(routeRegistry));
    }

    public event EventHandler<NavigationEventArgs>? Navigated;

    public object? CurrentView { get; private set; }

    public string? CurrentRoute { get; private set; }

    public void AttachHost(ContentControl host)
    {
        _host = host ?? throw new ArgumentNullException(nameof(host));
    }

    public void Navigate(string route)
    {
        var viewType = _routeRegistry.Resolve(route);
        var resolved = _serviceProvider.GetRequiredService(viewType);

        if (resolved is not UserControl view)
            throw new InvalidOperationException($"Resolved navigation target for route '{route}' is not a UserControl.");

        Navigate(view, route);
    }

    public void Navigate(UserControl view, string route)
    {
        if (view is null)
            throw new ArgumentNullException(nameof(view));

        if (route is null)
            throw new ArgumentNullException(nameof(route));

        CurrentView = view;
        CurrentRoute = route;

        if (_host is not null)
            _host.Content = view;

        Navigated?.Invoke(this, new NavigationEventArgs(view, route));
    }
}
