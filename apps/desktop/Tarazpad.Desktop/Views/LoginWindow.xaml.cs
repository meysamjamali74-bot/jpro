using System.Windows;
using Tarazpad.Desktop.Services;

namespace Tarazpad.Desktop.Views;

public partial class LoginWindow : Window
{
    private readonly AppSettings _settings;

    public LoginWindow()
    {
        InitializeComponent();
        _settings = AppSettings.Load();
        ServerBox.Text = _settings.ServerUrl;
        RememberServerBox.IsChecked = _settings.RememberServer;
        EmailBox.Text = "admin@tarazpad.local";
        Loaded += (_, _) => EmailBox.Focus();
    }

    private async void TestButton_Click(object sender, RoutedEventArgs e)
    {
        await RunBusy(async () =>
        {
            App.Api.Configure(ServerBox.Text);
            var ok = await App.Api.HealthAsync();
            StatusText.Foreground = ok
                ? new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(15, 157, 104))
                : new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(217, 54, 62));
            StatusText.Text = ok ? "اتصال به سرور برقرار است." : "سرور پاسخ سالم نداد.";
        });
    }

    private async void LoginButton_Click(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(EmailBox.Text) || string.IsNullOrWhiteSpace(PasswordBox.Password))
        {
            StatusText.Text = "نام کاربری و رمز عبور را وارد کنید.";
            return;
        }

        await RunBusy(async () =>
        {
            App.Api.Configure(ServerBox.Text);
            if (!await App.Api.HealthAsync()) throw new InvalidOperationException("سرور ترازپاد در دسترس نیست.");
            await App.Api.LoginAsync(EmailBox.Text.Trim(), PasswordBox.Password);

            if (RememberServerBox.IsChecked == true)
            {
                _settings.ServerUrl = ServerBox.Text.Trim();
                _settings.RememberServer = true;
                _settings.Save();
            }

            var main = new MainWindow();
            Application.Current.MainWindow = main;
            main.Show();
            Close();
        });
    }

    private async Task RunBusy(Func<Task> operation)
    {
        LoginButton.IsEnabled = false;
        TestButton.IsEnabled = false;
        StatusText.Foreground = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(100, 116, 139));
        StatusText.Text = "در حال بررسی...";
        try
        {
            await operation();
        }
        catch (Exception ex)
        {
            StatusText.Foreground = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(217, 54, 62));
            StatusText.Text = ex.Message;
        }
        finally
        {
            LoginButton.IsEnabled = true;
            TestButton.IsEnabled = true;
        }
    }
}
