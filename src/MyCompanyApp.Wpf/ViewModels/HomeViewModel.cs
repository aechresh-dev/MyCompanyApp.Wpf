using MyCompanyApp.Application.Core;

namespace MyCompanyApp.Wpf.ViewModels;

public sealed class HomeViewModel : BaseViewModel
{
    private string _title = "ط¯ط§ط´ط¨ظˆط±ط¯ ط§طµظ„ظٹ";
    private string _description = "ظ¾ط±ظˆعکظ‡ WPF ط§ع©ظ†ظˆظ† ط¯ط§ط±ط§ظٹ ط³ط§ط®طھط§ط± MVVM ط§ط³طھط§ظ†ط¯ط§ط±ط¯ ط§ط³طھ.";

    public string Title
    {
        get => _title;
        set => SetProperty(ref _title, value);
    }

    public string Description
    {
        get => _description;
        set => SetProperty(ref _description, value);
    }
}
