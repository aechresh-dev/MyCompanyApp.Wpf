using System;
using System.Windows.Controls;

namespace MyCompanyApp.Platform.UI.Navigation;

public sealed class NavigationEventArgs : EventArgs
{
    public NavigationEventArgs(UserControl view, string route)
    {
        View = view ?? throw new ArgumentNullException(nameof(view));
        Route = route ?? throw new ArgumentNullException(nameof(route));
    }

    public UserControl View { get; }

    public string Route { get; }
}
