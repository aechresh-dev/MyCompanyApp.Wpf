using System;
using System.Windows.Controls;
using Microsoft.Extensions.DependencyInjection;

namespace MyCompanyApp.Wpf.Core.Navigation;

public class NavigationService
{
    private readonly IServiceProvider _serviceProvider;
    private ContentControl? _host;

    public NavigationService(IServiceProvider serviceProvider)
    {
        _serviceProvider = serviceProvider;
    }

    public void SetHost(ContentControl host)
    {
        _host = host;
    }

    public void Navigate<TView>() where TView : UserControl
    {
        if (_host == null)
            throw new InvalidOperationException("Navigation host is not set.");

        var view = _serviceProvider.GetRequiredService<TView>();

        _host.Content = view;
    }
}