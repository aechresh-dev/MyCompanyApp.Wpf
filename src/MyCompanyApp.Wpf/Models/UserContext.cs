namespace MyCompanyApp.Wpf.Models;

public class UserContext
{
    public Guid UserId { get; set; }

    public string Username { get; set; } = "";

    public string DisplayName { get; set; } = "";

    public string Role { get; set; } = "";

    public bool IsAdmin => Role == "Admin";
}
