using System.Security.Cryptography;
using System.Text;

namespace Bestplus;

public static class Security
{
    public static string NewSalt() => Convert.ToHexString(RandomNumberGenerator.GetBytes(16));
    public static string HashPassword(string password, string salt)
    {
        using var sha = SHA256.Create();
        return Convert.ToHexString(sha.ComputeHash(Encoding.UTF8.GetBytes(salt + "|BESTPLUS|" + password)));
    }
    public static bool Verify(string password, string salt, string hash) =>
        string.Equals(HashPassword(password, salt), hash, StringComparison.OrdinalIgnoreCase);
}
