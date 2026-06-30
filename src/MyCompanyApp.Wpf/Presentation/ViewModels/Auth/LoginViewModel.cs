using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyCompanyApp.Application.Interfaces.Auth;

namespace MyCompanyApp.Wpf.Presentation.ViewModels.Auth
{
    public partial class LoginViewModel : ObservableObject
    {
        private readonly IAuthService _authService;

        public LoginViewModel(IAuthService authService)
        {
            _authService = authService;
            Username = string.Empty;
            Password = string.Empty;
            StatusMessage = string.Empty;
        }

        [ObservableProperty]
        private string username;

        [ObservableProperty]
        private string password;

        [ObservableProperty]
        private string statusMessage;

        [RelayCommand]
        private async Task LoginAsync()
        {
            StatusMessage = string.Empty;

            if (string.IsNullOrWhiteSpace(Username))
            {
                StatusMessage = "Username is required.";
                return;
            }

            if (string.IsNullOrWhiteSpace(Password))
            {
                StatusMessage = "Password is required.";
                return;
            }

            var result = await _authService.LoginAsync(Username, Password);

            if (result != null)
            {
                StatusMessage = "Login successful.";
            }
            else
            {
                StatusMessage = "Invalid username or password.";
            }
        }
    }
}

