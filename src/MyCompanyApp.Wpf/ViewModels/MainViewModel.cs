using MyCompanyApp.Application.Services;
using System.Windows.Input;
using MyCompanyApp.Wpf.Commands;
using MyCompanyApp.Application.Core;
using MyCompanyApp.Wpf.Services;

namespace MyCompanyApp.Wpf.ViewModels;

public sealed class MainViewModel : BaseViewModel
{
    private readonly INavigationService _navigationService;

    public MainViewModel(INavigationService navigationService)
    {
        _navigationService = navigationService;
        NavigateHomeCommand = new RelayCommand(NavigateHome);
    }

    public BaseViewModel CurrentViewModel => _navigationService.CurrentViewModel;

    public ICommand NavigateHomeCommand { get; }

    private void NavigateHome()
    {
        _navigationService.NavigateTo<HomeViewModel>();
        OnPropertyChanged(nameof(CurrentViewModel));
    }
}

