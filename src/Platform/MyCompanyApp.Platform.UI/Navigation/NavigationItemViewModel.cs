using System;
using System.Windows.Input;

namespace MyCompanyApp.Platform.UI.Navigation;

public sealed class NavigationItemViewModel
{
    public string Id { get; }
    public string Title { get; }

    public string RouteKey { get; }
    public string RequiredPermission { get; }
    public string Icon { get; }

    public ICommand Command { get; }

    public NavigationItemViewModel(
        string id,
        string title,
        string routeKeyOrPermission)
        : this(
            id,
            title,
            routeKeyOrPermission,
            routeKeyOrPermission,
            string.Empty,
            () => { })
    {
    }

    public NavigationItemViewModel(
        string id,
        string title,
        Action navigateAction)
        : this(
            id,
            title,
            id,
            string.Empty,
            string.Empty,
            navigateAction)
    {
    }

    public NavigationItemViewModel(
        string id,
        string title,
        string routeKey,
        Action navigateAction)
        : this(
            id,
            title,
            routeKey,
            string.Empty,
            string.Empty,
            navigateAction)
    {
    }

    public NavigationItemViewModel(
        string id,
        string title,
        string routeKey,
        string requiredPermission,
        string icon,
        Action navigateAction)
    {
        if (string.IsNullOrWhiteSpace(id))
            throw new ArgumentException("Navigation item id cannot be null or empty.", nameof(id));

        if (string.IsNullOrWhiteSpace(title))
            throw new ArgumentException("Navigation item title cannot be null or empty.", nameof(title));

        Id = id;
        Title = title;
        RouteKey = string.IsNullOrWhiteSpace(routeKey) ? id : routeKey;
        RequiredPermission = requiredPermission ?? string.Empty;
        Icon = icon ?? string.Empty;

        Command = new RelayCommand(navigateAction ?? (() => { }));
    }
}
