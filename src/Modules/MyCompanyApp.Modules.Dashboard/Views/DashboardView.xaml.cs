using System.Windows.Controls;
using MyCompanyApp.Modules.Dashboard.ViewModels;

namespace MyCompanyApp.Modules.Dashboard.Views
{
    public partial class DashboardView : UserControl
    {
        public DashboardView()
        {
            InitializeComponent();
            DataContext = new DashboardViewModel();
        }
    }
}