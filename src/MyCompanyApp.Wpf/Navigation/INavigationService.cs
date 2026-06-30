namespace MyCompanyApp.Wpf.Navigation;

public interface INavigationService
{
    void Navigate<TViewModel>() where TViewModel:class;
}
