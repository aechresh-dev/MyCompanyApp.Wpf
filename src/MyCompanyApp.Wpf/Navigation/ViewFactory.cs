using MyCompanyApp.Platform.Core.Navigation;

namespace MyCompanyApp.Wpf.Navigation;

public class ViewFactory : IViewFactory
{
    public object Create(string viewName)
    {
        return viewName switch
        {
            _ => throw new System.Exception($"View not registered: {viewName}")
        };
    }
}
