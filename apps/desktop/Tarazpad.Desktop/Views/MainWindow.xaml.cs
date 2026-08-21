using System.Windows;
using System.Windows.Controls;
using Tarazpad.Desktop.Infrastructure;

namespace Tarazpad.Desktop.Views;

public partial class MainWindow : Window
{
    private FrameworkElement? _current;

    public MainWindow()
    {
        InitializeComponent();
        UserText.Text = App.Api.UserName ?? "کاربر ترازپاد";
        ServerText.Text = App.Api.ServerUrl;
        Loaded += (_, _) => ShowDashboard();
    }

    private void NavButton_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not Button { Tag: string key }) return;
        try
        {
            switch (key)
            {
                case "dashboard": ShowDashboard(); break;
                case "tasks": ShowSingle("tasks"); break;
                case "accounting": ShowTabs("حسابداری و اسناد", "کدینگ، تراز و کنترل دوره مالی", "accounts", "accounting", "fiscal-years", "close-runs"); break;
                case "treasury": ShowTabs("خزانه‌داری", "بانک، دریافت، پرداخت و اسناد تجاری", "treasury-receipts", "treasury-payments", "bank-accounts", "cheques"); break;
                case "cashflow": ShowReportCenter("CASH_FLOW"); break;
                case "assets": ShowTabs("دارایی ثابت", "طبقات اموال، دارایی‌ها و استهلاک", "assets", "asset-classes", "depreciation-runs"); break;
                case "tax": ShowTaxCenter(); break;
                case "sales": ShowSingle("sales"); break;
                case "purchases": ShowTabs("خرید و تأمین", "فاکتور خرید، دریافت کالا و کنترل تطبیق", "purchase-invoices", "goods-receipts"); break;
                case "inventory": ShowSingle("inventory"); break;
                case "logistics": ShowSingle("logistics"); break;
                case "parties": ShowSingle("parties"); break;
                case "crm": ShowSingle("crm"); break;
                case "hr": ShowTabs("منابع انسانی و حقوق", "پرسنل، قرارداد، سمت و محاسبات حقوق", "employees", "contracts", "positions", "payroll-batches", "payroll-legal"); break;
                case "reports": ShowReportCenter(null); break;
                case "settings": ShowSettings(); break;
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "ترازپاد", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private void ShowDashboard()
    {
        PageTitle.Text = "داشبورد مدیریتی";
        PageSubtitle.Text = "نمای یکپارچه وضعیت مالی و عملیاتی";
        SetContent(new DashboardView());
    }

    private void ShowSingle(string key)
    {
        var d = RequireDefinition(key);
        PageTitle.Text = d.Title;
        PageSubtitle.Text = d.Subtitle;
        SetContent(new DataModuleView(d));
    }

    private void ShowTabs(string title, string subtitle, params string[] keys)
    {
        PageTitle.Text = title;
        PageSubtitle.Text = subtitle;
        SetContent(new TabbedModuleView(keys.Select(RequireDefinition)));
    }

    private void ShowReportCenter(string? initialReport)
    {
        PageTitle.Text = initialReport == "CASH_FLOW" ? "جریان وجوه نقد" : "گزارش‌ها و تحلیل مالی";
        PageSubtitle.Text = "تراز آزمایشی، سود و زیان، ترازنامه و جریان نقد";
        SetContent(new ReportCenterView(initialReport));
    }

    private void ShowTaxCenter()
    {
        PageTitle.Text = "مالیات و سامانه مؤدیان";
        PageSubtitle.Text = "پروفایل مالیاتی شرکت و نرخ‌های مؤثر";
        SetContent(new TaxCenterView());
    }

    private void ShowSettings()
    {
        PageTitle.Text = "تنظیمات و دسترسی";
        PageSubtitle.Text = "تنظیمات کلاینت ویندوز، سرور و اطلاعات نشست";
        SetContent(new SettingsView());
    }

    private void SetContent(FrameworkElement element)
    {
        _current = element;
        ContentHost.Content = element;
        StatusBarText.Text = "آماده";
    }

    private static ModuleDefinition RequireDefinition(string key)
        => NativeModuleOverrides.Get(key) ?? throw new InvalidOperationException($"ماژول {key} تعریف نشده است.");

    private async void RefreshButton_Click(object sender, RoutedEventArgs e)
    {
        StatusBarText.Text = "در حال بازخوانی...";
        try
        {
            switch (_current)
            {
                case DashboardView d: await d.RefreshAsync(); break;
                case DataModuleView d: await d.RefreshAsync(); break;
                case TabbedModuleView t: await t.RefreshAsync(); break;
                case ReportCenterView r: await r.RefreshAsync(); break;
                case TaxCenterView t: await t.RefreshAsync(); break;
                case SettingsView s: await s.RefreshAsync(); break;
            }
            StatusBarText.Text = $"بروزرسانی شد - {PersianDate.Today()} {DateTime.Now:HH:mm:ss}";
        }
        catch (Exception ex)
        {
            StatusBarText.Text = ex.Message;
        }
    }

    private void LogoutButton_Click(object sender, RoutedEventArgs e)
    {
        var login = new LoginWindow();
        Application.Current.MainWindow = login;
        login.Show();
        Close();
    }
}
