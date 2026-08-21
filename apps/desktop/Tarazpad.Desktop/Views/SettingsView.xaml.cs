using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using Tarazpad.Desktop.Services;

namespace Tarazpad.Desktop.Views;

public partial class SettingsView : UserControl
{
    public SettingsView()
    {
        InitializeComponent();
        ServerBox.Text = App.Api.ServerUrl;
        ConfigPathText.Text = AppSettings.SettingsPath;
        Loaded += async (_, _) => await RefreshAsync();
    }

    public async Task RefreshAsync()
    {
        try
        {
            var runtime = await App.Api.GetJsonAsync("api/system/runtime");
            RuntimeModeText.Text = Get(runtime, "mode", "OFFLINE_LAN");
            DatabaseText.Text = Get(runtime, "database", "MySQL");
            InternetText.Text = GetBool(runtime, "internetRequired") ? "بله" : "خیر";
        }
        catch (Exception ex)
        {
            RuntimeModeText.Text = "خطا";
            DatabaseText.Text = "—";
            InternetText.Text = "—";
            StatusText.Foreground = System.Windows.Media.Brushes.IndianRed;
            StatusText.Text = ex.Message;
        }
    }

    private async void TestButton_Click(object sender, RoutedEventArgs e)
    {
        await WithBusy(async () =>
        {
            var previous = App.Api.ServerUrl;
            try
            {
                App.Api.Configure(ServerBox.Text);
                if (!await App.Api.HealthAsync()) throw new InvalidOperationException("سرور پاسخ سالم نداد.");
                StatusText.Foreground = System.Windows.Media.Brushes.SeaGreen;
                StatusText.Text = "اتصال به سرور برقرار است.";
            }
            catch
            {
                App.Api.Configure(previous);
                throw;
            }
        });
    }

    private async void SaveButton_Click(object sender, RoutedEventArgs e)
    {
        await WithBusy(async () =>
        {
            var previous = App.Api.ServerUrl;
            try
            {
                App.Api.Configure(ServerBox.Text);
                if (!await App.Api.HealthAsync()) throw new InvalidOperationException("آدرس جدید پاسخ سالم نداد؛ تنظیمات ذخیره نشد.");
                new AppSettings { ServerUrl = ServerBox.Text.Trim(), RememberServer = true }.Save();
                StatusText.Foreground = System.Windows.Media.Brushes.SeaGreen;
                StatusText.Text = "آدرس سرور ذخیره شد. برای نشست جدید، در صورت تغییر سرور دوباره وارد شوید.";
            }
            catch
            {
                App.Api.Configure(previous);
                throw;
            }
        });
    }

    private async Task WithBusy(Func<Task> action)
    {
        TestButton.IsEnabled = SaveButton.IsEnabled = false;
        try { await action(); }
        catch (Exception ex)
        {
            StatusText.Foreground = System.Windows.Media.Brushes.IndianRed;
            StatusText.Text = ex.Message;
        }
        finally { TestButton.IsEnabled = SaveButton.IsEnabled = true; }
    }

    private static string Get(JsonElement e, string name, string fallback)
        => e.ValueKind == JsonValueKind.Object && e.TryGetProperty(name, out var v) ? (v.ValueKind == JsonValueKind.String ? v.GetString() ?? fallback : v.ToString()) : fallback;

    private static bool GetBool(JsonElement e, string name)
        => e.ValueKind == JsonValueKind.Object && e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.True;
}
