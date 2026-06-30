using MyCompanyApp.Application.Core;

namespace MyCompanyApp.Application.Services;

public interface INavigationService
{
    BaseViewModel CurrentViewModel { get; }

    void NavigateTo<TViewModel>() where TViewModel : BaseViewModel;
}
