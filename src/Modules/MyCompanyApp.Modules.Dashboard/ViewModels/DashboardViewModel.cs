using System.Windows.Input;
using MyCompanyApp.Platform.UI.Mvvm;

namespace MyCompanyApp.Modules.Dashboard.ViewModels
{
    public sealed class DashboardViewModel : ViewModelBase
    {
        private int _usersCount = 128;
        private int _leaveRequestsCount = 24;
        private int _notificationsCount = 7;

        public DashboardViewModel()
        {
            Title = "Dashboard";
            StatusMessage = "System is ready.";
            RefreshCommand = new RelayCommand(Refresh);
        }

        public int UsersCount
        {
            get => _usersCount;
            private set => SetProperty(ref _usersCount, value);
        }

        public int LeaveRequestsCount
        {
            get => _leaveRequestsCount;
            private set => SetProperty(ref _leaveRequestsCount, value);
        }

        public int NotificationsCount
        {
            get => _notificationsCount;
            private set => SetProperty(ref _notificationsCount, value);
        }

        public ICommand RefreshCommand { get; }

        private void Refresh()
        {
            NotificationsCount++;
            StatusMessage = "Dashboard refreshed successfully.";
        }
    }
}

