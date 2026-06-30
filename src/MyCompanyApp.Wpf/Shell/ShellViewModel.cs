using MyCompanyApp.Wpf.Navigation;

namespace MyCompanyApp.Wpf.Shell;

public class ShellViewModel
{
    public NavigationStore NavigationStore {get;}

    public object? CurrentViewModel => NavigationStore.CurrentViewModel;

    public ShellViewModel(NavigationStore store)
    {
        NavigationStore=store;
    }
}
