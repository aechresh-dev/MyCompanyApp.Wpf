using System.Windows.Controls;

namespace MyCompanyApp.Wpf.Services;

public class NavigationService
{
    private Frame? _frame;

    public void Initialize(Frame frame)
    {
        _frame = frame;
    }

    public void Navigate(Page page)
    {
        _frame?.Navigate(page);
    }
}
