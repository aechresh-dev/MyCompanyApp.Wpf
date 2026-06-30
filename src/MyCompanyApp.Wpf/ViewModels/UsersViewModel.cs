using System.Collections.ObjectModel;
using MyCompanyApp.Platform.UI.MVVM;
using MyCompanyApp.Modules.Users.Services;
using MyCompanyApp.Modules.Users.Commands;
using MyCompanyApp.Modules.Users.DTOs;

namespace MyCompanyApp.Wpf.ViewModels;

public sealed class UsersViewModel : ViewModelBase
{
    private readonly IUserService _userService;

    public ObservableCollection<UserDto> Users { get; } = new();

    private string _username = "";
    public string Username
    {
        get => _username;
        set => SetProperty(ref _username, value);
    }

    public RelayCommand AddUserCommand { get; }

    public UsersViewModel(IUserService userService)
    {
        _userService = userService;
        AddUserCommand = new RelayCommand(AddUser);
    }

    private async void AddUser()
    {
        var result = await _userService.CreateUserAsync(new CreateUserCommand
        {
            Username = Username,
            DisplayName = Username
        });

        if (result.IsSuccess && result.Value != null)
        {
            Users.Add(result.Value);
            Username = "";
        }
    }
}
