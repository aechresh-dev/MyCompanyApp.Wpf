using MyCompanyApp.Application.Core;

namespace MyCompanyApp.Wpf.ViewModels;

public class DashboardViewModel : BaseViewModel
{
    private string _welcomeText = "Welcome to MyCompany Dashboard";

    public string WelcomeText
    {
        get => _welcomeText;
        set => SetProperty(ref _welcomeText, value);
    }
}
