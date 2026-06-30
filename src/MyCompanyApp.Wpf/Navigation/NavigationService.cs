using Microsoft.Extensions.DependencyInjection;

namespace MyCompanyApp.Wpf.Navigation;

public class NavigationService : INavigationService
{
    private readonly IServiceProvider _provider;
    private readonly NavigationStore _store;

    public NavigationService(IServiceProvider provider,NavigationStore store)
    {
        _provider=provider;
        _store=store;
    }

    public void Navigate<TViewModel>() where TViewModel:class
    {
        var vm=_provider.GetRequiredService<TViewModel>();
        _store.CurrentViewModel=vm;
    }
}
