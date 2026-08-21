using System.Text.Json;

namespace Tarazpad.Desktop.Services;

public sealed class AppSettings
{
    public string ServerUrl { get; set; } = "http://127.0.0.1:8080";
    public bool RememberServer { get; set; } = true;

    public static string SettingsDirectory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
        "Tarazpad", "client");

    public static string SettingsPath => Path.Combine(SettingsDirectory, "client.json");

    public static AppSettings Load()
    {
        try
        {
            if (!File.Exists(SettingsPath)) return new AppSettings();
            return JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(SettingsPath)) ?? new AppSettings();
        }
        catch
        {
            return new AppSettings();
        }
    }

    public void Save()
    {
        Directory.CreateDirectory(SettingsDirectory);
        File.WriteAllText(SettingsPath, JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
    }
}
