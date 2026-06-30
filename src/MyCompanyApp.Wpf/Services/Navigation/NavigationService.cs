using System;
using System.Windows;
using Microsoft.Extensions.DependencyInjection;
using MyCompanyApp.Wpf.Presentation.Windows;

namespace MyCompanyApp.Wpf.Services.Navigation;

public sealed class NavigationService : INavigationService
{
    private readonly IServiceProvider _serviceProvider;

    public NavigationService(IServiceProvider serviceProvider)
    {
        _serviceProvider = serviceProvider;
    }

    public void ShowDashboard(Window? currentWindow = null)
    {
        var dashboardWindow = _serviceProvider.GetRequiredService<DashboardWindow>();
        System.Windows.Application.Current.MainWindow = dashboardWindow;
        dashboardWindow.Show();
        currentWindow?.Close();
    }
}

