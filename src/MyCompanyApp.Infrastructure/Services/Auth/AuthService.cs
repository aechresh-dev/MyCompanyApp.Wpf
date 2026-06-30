using MyCompanyApp.Application.Interfaces.Auth;
using MyCompanyApp.Application.Models.Auth;

namespace MyCompanyApp.Infrastructure.Services.Auth;

public sealed class AuthService : IAuthService
{
    public Task<LoginResult> LoginAsync(string username, string password)
    {
        username = (username ?? string.Empty).Trim();
        password = password ?? string.Empty;

        if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(password))
        {
            return Task.FromResult(new LoginResult
            {
                Success = false,
                Message = "نام کاربری و رمز عبور الزامی است."
            });
        }

        // Temporary roadmap-safe development login.
        // Later this should be replaced by database-backed authentication.
        if (string.Equals(username, "admin", StringComparison.OrdinalIgnoreCase) &&
            password == "admin123")
        {
            return Task.FromResult(new LoginResult
            {
                Success = true,
                Username = "admin",
                DisplayName = "مدیر سیستم",
                Message = "ورود موفقیت‌آمیز بود."
            });
        }

        return Task.FromResult(new LoginResult
        {
            Success = false,
            Message = "نام کاربری یا رمز عبور اشتباه است."
        });
    }
}
