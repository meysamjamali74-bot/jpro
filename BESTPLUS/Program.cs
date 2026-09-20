using System.Globalization;
using Bestplus.Data;
using Bestplus.UI;

namespace Bestplus;

internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        if (args.Any(x => string.Equals(x, "--self-test", StringComparison.OrdinalIgnoreCase)))
        {
            try { Database.Initialize(); return Database.ScalarText("PRAGMA integrity_check;") == "ok" ? 0 : 2; }
            catch (Exception ex) { ErrorReporter.Log(ex); return 3; }
        }

        ApplicationConfiguration.Initialize();
        CultureInfo.DefaultThreadCurrentCulture = CultureInfo.GetCultureInfo("fa-IR");
        CultureInfo.DefaultThreadCurrentUICulture = CultureInfo.GetCultureInfo("fa-IR");

        Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
        Application.ThreadException += (_, e) => ErrorReporter.Show(e.Exception);
        AppDomain.CurrentDomain.UnhandledException += (_, e) =>
        {
            if (e.ExceptionObject is Exception ex) ErrorReporter.Log(ex);
        };

        Database.Initialize();
        using var login = new LoginForm();
        if (login.ShowDialog() != DialogResult.OK) return 0;
        Application.Run(new MainForm(login.AuthenticatedUserId, login.AuthenticatedUserName, login.AuthenticatedRole));
        return 0;
    }
}

internal static class ErrorReporter
{
    public static void Log(Exception ex)
    {
        try
        {
            Directory.CreateDirectory(AppPaths.LogDir);
            File.AppendAllText(Path.Combine(AppPaths.LogDir, $"bestplus-{DateTime.Now:yyyyMMdd}.log"),
                $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {ex}\r\n\r\n", System.Text.Encoding.UTF8);
        }
        catch { }
    }

    public static void Show(Exception ex)
    {
        Log(ex);
        MessageBox.Show("یک خطای غیرمنتظره رخ داد. جزئیات در پوشه Logs ذخیره شد.\n\n" + ex.Message,
            "BESTPLUS", MessageBoxButtons.OK, MessageBoxIcon.Error);
    }
}
