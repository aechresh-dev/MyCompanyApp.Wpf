using System;
using System.Windows.Controls;

namespace MyCompanyApp.Platform.UI.Navigation;

public interface INavigationService
{
    event EventHandler<NavigationEventArgs>? Navigated;

    object? CurrentView { get; }
    string? CurrentRoute { get; }

    void AttachHost(ContentControl host);

    void Navigate(string route);
    void Navigate(UserControl view, string route);
}
