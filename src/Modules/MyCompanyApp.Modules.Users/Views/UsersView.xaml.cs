using System.Windows.Controls;
using MyCompanyApp.Modules.Users.ViewModels;

namespace MyCompanyApp.Modules.Users.Views
{
    public partial class UsersView : UserControl
    {
        public UsersView()
        {
            InitializeComponent();
            DataContext = new UsersViewModel();
        }
    }
}