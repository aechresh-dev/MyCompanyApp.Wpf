namespace MyCompanyApp.Modules.Users.Commands;

public sealed class CreateUserCommand
{
    public string Username { get; init; } = "";
    public string DisplayName { get; init; } = "";
}
