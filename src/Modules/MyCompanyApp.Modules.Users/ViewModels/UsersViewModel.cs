using System.Collections.ObjectModel;
using System.Windows.Input;
using MyCompanyApp.Platform.UI.Mvvm;

namespace MyCompanyApp.Modules.Users.ViewModels
{
    public sealed class UsersViewModel : ViewModelBase
    {
        private string _selectedUserName = string.Empty;

        public UsersViewModel()
        {
            Title = "Users Management";
            StatusMessage = "Sample users loaded.";

            Users = new ObservableCollection<string>
            {
                "Amir Rezaei - System Admin",
                "Sara Mohammadi - HR",
                "Ali Karimi - Sales Staff",
                "Negar Ahmadi - Accounting"
            };

            SelectFirstUserCommand = new RelayCommand(SelectFirstUser);
        }

        public ObservableCollection<string> Users { get; }

        public string SelectedUserName
        {
            get => _selectedUserName;
            set => SetProperty(ref _selectedUserName, value);
        }

        public ICommand SelectFirstUserCommand { get; }

        private void SelectFirstUser()
        {
            if (Users.Count > 0)
            {
                SelectedUserName = Users[0];
                StatusMessage = "Selected user: " + SelectedUserName;
            }
        }
    }
}

