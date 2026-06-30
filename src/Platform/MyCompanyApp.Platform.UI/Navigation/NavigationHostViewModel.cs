using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace MyCompanyApp.Platform.UI.Navigation
{
    public sealed class NavigationHostViewModel : INotifyPropertyChanged
    {
        private readonly NavigationService _navigationService;
        private object? _currentView;

        public NavigationHostViewModel(NavigationService navigationService)
        {
            _navigationService = navigationService;
            _currentView = navigationService.CurrentView;

            _navigationService.Navigated += (_, args) =>
            {
                CurrentView = args.View;
            };
        }

        public object? CurrentView
        {
            get => _currentView;
            private set
            {
                if (!ReferenceEquals(_currentView, value))
                {
                    _currentView = value;
                    OnPropertyChanged();
                }
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        private void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
