using System.Windows;
using MyCompanyApp.Wpf.Core.Navigation;
using MyCompanyApp.Wpf.Views;

namespace MyCompanyApp.Wpf;

public partial class AppShell : Window
{
    private readonly NavigationService _navigation;

    public AppShell(NavigationService navigation)
    {
        InitializeComponent();

        _navigation = navigation;
        _navigation.SetHost(MainContent);
        _navigation.Navigate<DashboardView>();
    }

    private void DashboardButton_Click(object sender, RoutedEventArgs e)
    {
        _navigation.Navigate<DashboardView>();
    }

    private void UsersButton_Click(object sender, RoutedEventArgs e)
    {
        _navigation.Navigate<UsersView>();
    }

    private void LeaveButton_Click(object sender, RoutedEventArgs e)
    {
        _navigation.Navigate<LeaveView>();
    }
}