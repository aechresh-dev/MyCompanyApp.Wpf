using System;
using System.Windows.Controls;
using MyCompanyApp.Platform.Core.Navigation;
using System.Collections.Generic;
using System.Linq;
using MyCompanyApp.Application.Modules;
using MyCompanyApp.Platform.UI.Navigation;

namespace MyCompanyApp.Platform.UI.Navigation;

public sealed class MainNavigationService
{
    private readonly IModuleCatalog _moduleCatalog;
    private readonly INavigationService _navigationService;
    private readonly IViewFactory _IViewFactory;

    public MainNavigationService(
    IModuleCatalog moduleCatalog,
    INavigationService INavigationService,
    IViewFactory IViewFactory)
    {
    _moduleCatalog = moduleCatalog;
    _navigationService = INavigationService;
    _IViewFactory = IViewFactory;
    }

    public IReadOnlyList<NavigationItemViewModel> GetNavigationItems()
    {
        return _moduleCatalog
            .GetAvailableModules()
            .OrderBy(x => x.SortOrder)
            .Select(module => new NavigationItemViewModel(
                module.Id,
                module.DisplayName,
                module.Id,
                module.RequiredPermission ?? string.Empty,
                module.Icon ?? string.Empty,
                () => _navigationService.Navigate(ToUserControl(_IViewFactory.Create(module.Id)), module.Id)))
            .ToList();
    }

    public void NavigateToDefault()
    {
        var firstModule = _moduleCatalog
            .GetAvailableModules()
            .OrderBy(x => x.SortOrder)
            .FirstOrDefault();

        if (firstModule is null)
            return;

        _navigationService.Navigate(ToUserControl(_IViewFactory.Create(firstModule.Id)), firstModule.Id);
    }

    
    public IReadOnlyList<NavigationItemViewModel> GetItems()
    {
        return GetNavigationItems();
    }
private static UserControl ToUserControl(object view)
    {
        if (view is UserControl userControl)
        {
            return userControl;
        }

        throw new InvalidOperationException("ViewFactory returned an invalid view instance. Expected System.Windows.Controls.UserControl, but got " + (view?.GetType().FullName ?? "null") + ".");
    }
}


