using System.Windows.Controls;
using MyCompanyApp.Modules.Leave.ViewModels;

namespace MyCompanyApp.Modules.Leave.Views
{
    public partial class LeaveView : UserControl
    {
        public LeaveView()
        {
            InitializeComponent();
            DataContext = new LeaveViewModel();
        }
    }
}