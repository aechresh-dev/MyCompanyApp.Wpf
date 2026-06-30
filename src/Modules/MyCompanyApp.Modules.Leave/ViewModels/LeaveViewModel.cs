using System.Collections.ObjectModel;
using System.Windows.Input;
using MyCompanyApp.Platform.UI.Mvvm;

namespace MyCompanyApp.Modules.Leave.ViewModels
{
    public sealed class LeaveViewModel : ViewModelBase
    {
        private int _pendingRequestsCount = 2;

        public LeaveViewModel()
        {
            Title = "Leave Management";
            StatusMessage = "Sample leave requests loaded.";

            Requests = new ObservableCollection<string>
            {
                "Annual Leave Request - Sara Mohammadi - Pending",
                "Medical Leave Request - Ali Karimi - Pre-approved",
                "Hourly Leave Request - Negar Ahmadi - Pending"
            };

            ApproveOneCommand = new RelayCommand(ApproveOne);
        }

        public ObservableCollection<string> Requests { get; }

        public int PendingRequestsCount
        {
            get => _pendingRequestsCount;
            private set => SetProperty(ref _pendingRequestsCount, value);
        }

        public ICommand ApproveOneCommand { get; }

        private void ApproveOne()
        {
            if (PendingRequestsCount > 0)
            {
                PendingRequestsCount--;
                StatusMessage = "One leave request approved.";
            }
        }
    }
}

