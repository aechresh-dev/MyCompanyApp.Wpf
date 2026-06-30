using System.Collections.ObjectModel;

namespace MyCompanyApp.Platform.UI.Navigation;

public sealed class MainNavigationViewModel
{
    public ObservableCollection<NavigationItemViewModel> Items { get; }

    public MainNavigationViewModel(MainNavigationService navigationService)
    {
        Items = new ObservableCollection<NavigationItemViewModel>(navigationService.GetItems());
        navigationService.NavigateToDefault();
    }
}
