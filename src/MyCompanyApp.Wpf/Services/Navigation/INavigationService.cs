using System.Windows;

namespace MyCompanyApp.Wpf.Services.Navigation;

public interface INavigationService
{
    void ShowDashboard(Window? currentWindow = null);
}
