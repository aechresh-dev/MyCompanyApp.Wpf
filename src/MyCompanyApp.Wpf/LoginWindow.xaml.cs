using System;
using System.Threading.Tasks;
using System.Windows;
using MyCompanyApp.Application.Interfaces.Auth;

namespace MyCompanyApp.Wpf;

public partial class LoginWindow : Window
{
    private readonly IAuthService _authService;

    public LoginWindow(IAuthService authService)
    {
        _authService = authService ?? throw new ArgumentNullException(nameof(authService));
        InitializeComponent();
    }

    public string? AuthenticatedUsername { get; private set; }

    public string? AuthenticatedDisplayName { get; private set; }

    private async void LoginButton_Click(object sender, RoutedEventArgs e)
    {
        await TryLoginAsync();
    }

    private async Task TryLoginAsync()
    {
        try
        {
            SetBusy(true);
            ErrorTextBlock.Text = string.Empty;

            var username = UsernameTextBox.Text;
            var password = PasswordBox.Password;

            var result = await _authService.LoginAsync(username, password);

            if (result.Success)
            {
                AuthenticatedUsername = result.Username;
                AuthenticatedDisplayName = result.DisplayName;

                DialogResult = true;
                Close();
                return;
            }

            ErrorTextBlock.Text = string.IsNullOrWhiteSpace(result.Message)
                ? "ورود ناموفق بود."
                : result.Message;
        }
        catch (Exception ex)
        {
            ErrorTextBlock.Text = "خطا در فرآیند ورود: " + ex.Message;
        }
        finally
        {
            SetBusy(false);
        }
    }

    private void SetBusy(bool isBusy)
    {
        LoginButton.IsEnabled = !isBusy;
        UsernameTextBox.IsEnabled = !isBusy;
        PasswordBox.IsEnabled = !isBusy;
        LoginButton.Content = isBusy ? "در حال بررسی..." : "ورود";
    }
}
