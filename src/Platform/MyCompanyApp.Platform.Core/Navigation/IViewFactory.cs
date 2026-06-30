namespace MyCompanyApp.Platform.Core.Navigation;

public interface IViewFactory
{
    object Create(string viewName);
}
