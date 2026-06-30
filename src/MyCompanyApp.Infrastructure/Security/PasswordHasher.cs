using System.Security.Cryptography;
using System.Text;

namespace MyCompanyApp.Infrastructure.Security;

public static class PasswordHasher
{
    public static string HashPassword(string password)
    {
        byte[] salt = RandomNumberGenerator.GetBytes(16);

        var pbkdf2 = new Rfc2898DeriveBytes(password, salt, 10000, HashAlgorithmName.SHA256);

        byte[] hash = pbkdf2.GetBytes(32);

        return Convert.ToBase64String(salt) + "." + Convert.ToBase64String(hash);
    }

    public static bool Verify(string password,string stored)
    {
        var parts = stored.Split('.');

        byte[] salt = Convert.FromBase64String(parts[0]);
        byte[] hash = Convert.FromBase64String(parts[1]);

        var pbkdf2 = new Rfc2898DeriveBytes(password, salt, 10000, HashAlgorithmName.SHA256);

        byte[] newHash = pbkdf2.GetBytes(32);

        return newHash.SequenceEqual(hash);
    }
}
