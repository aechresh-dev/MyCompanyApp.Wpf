using System.Windows.Controls;
using MyCompanyApp.Wpf.ViewModels;

namespace MyCompanyApp.Wpf.Views.Dashboard;

public partial class DashboardView : Page
{
    public DashboardView()
    {
        InitializeComponent();
        DataContext = new DashboardViewModel();
    }
}
