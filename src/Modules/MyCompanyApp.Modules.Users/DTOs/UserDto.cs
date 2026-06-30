namespace MyCompanyApp.Modules.Users.DTOs;

public sealed class UserDto
{
    public Guid Id { get; set; }
    public string Username { get; set; } = "";
    public string DisplayName { get; set; } = "";
    public DateTime CreatedAt { get; set; }
}
