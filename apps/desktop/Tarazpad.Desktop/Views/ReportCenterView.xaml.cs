using System.Data;
using System.Globalization;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using Tarazpad.Desktop.Infrastructure;

namespace Tarazpad.Desktop.Views;

public partial class ReportCenterView : UserControl
{
    private readonly string? _initialReport;
    private string ReportType => (ReportTypeBox.SelectedItem as ComboBoxItem)?.Tag?.ToString() ?? "TRIAL_BALANCE";

    public ReportCenterView(string? initialReport)
    {
        InitializeComponent();
        _initialReport = initialReport;
        var today = PersianDate.Today();
        FromBox.Text = today[..4] + "/01/01";
        ToBox.Text = today;
        ReportTypeBox.SelectedIndex = initialReport switch
        {
            "PROFIT_LOSS" => 1,
            "BALANCE_SHEET" => 2,
            "CASH_FLOW" => 3,
            _ => 0
        };
        Loaded += async (_, _) => await RefreshAsync();
    }

    public async Task RefreshAsync()
    {
        await ExecuteReportAsync();
    }

    private async void RunButton_Click(object sender, RoutedEventArgs e) => await ExecuteReportAsync();

    private void ReportTypeBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (!IsLoaded) return;
        ApplyReportLabels();
    }

    private void ApplyReportLabels()
    {
        var balance = ReportType == "BALANCE_SHEET";
        FromBox.IsEnabled = !balance;
        ToLabel.Text = balance ? "تاریخ گزارش (شمسی)" : "تا تاریخ (شمسی)";
    }

    private async Task ExecuteReportAsync()
    {
        LoadingPanel.Visibility = Visibility.Visible;
        ErrorText.Visibility = Visibility.Collapsed;
        RunButton.IsEnabled = false;
        try
        {
            ApplyReportLabels();
            var to = PersianDate.ToIso(ToBox.Text);
            var from = ReportType == "BALANCE_SHEET" ? null : PersianDate.ToIso(FromBox.Text);
            JsonElement json;
            switch (ReportType)
            {
                case "TRIAL_BALANCE":
                    json = await App.Api.GetJsonAsync($"api/iran/finance/trial-balance-v6?dateFrom={from}&dateTo={to}&level=9");
                    ShowTrialBalance(json);
                    break;
                case "PROFIT_LOSS":
                    json = await App.Api.GetJsonAsync($"api/iran/finance/profit-loss?dateFrom={from}&dateTo={to}");
                    ShowProfitLoss(json);
                    break;
                case "BALANCE_SHEET":
                    json = await App.Api.GetJsonAsync($"api/iran/finance/balance-sheet?asOf={to}");
                    ShowBalanceSheet(json);
                    break;
                case "CASH_FLOW":
                    json = await App.Api.GetJsonAsync($"api/iran/finance/cash-flow?dateFrom={from}&dateTo={to}");
                    ShowCashFlow(json);
                    break;
            }
        }
        catch (Exception ex)
        {
            ReportGrid.ItemsSource = null;
            ErrorText.Text = ex.Message;
            ErrorText.Visibility = Visibility.Visible;
            ResetSummary();
        }
        finally
        {
            RunButton.IsEnabled = true;
            LoadingPanel.Visibility = Visibility.Collapsed;
        }
    }

    private void ShowTrialBalance(JsonElement root)
    {
        var table = JsonTable.ToDataTable(JsonTable.ExtractRows(root, "rows"));
        ReportGrid.ItemsSource = table.DefaultView;
        Summary1Label.Text = "جمع بدهکار"; Summary1.Text = Money(root, "totalDebit");
        Summary2Label.Text = "جمع بستانکار"; Summary2.Text = Money(root, "totalCredit");
        Summary3Label.Text = "اختلاف"; Summary3.Text = Format(GetDecimal(root, "totalDebit") - GetDecimal(root, "totalCredit"));
        Summary4Label.Text = "تعداد حساب"; Summary4.Text = table.Rows.Count.ToString("N0");
    }

    private void ShowProfitLoss(JsonElement root)
    {
        var current = root.GetProperty("current");
        ReportGrid.ItemsSource = SectionTable(current.GetProperty("sections"), new Dictionary<string, string>
        {
            ["OPERATING_REVENUE"]="درآمد عملیاتی", ["COST_OF_SALES"]="بهای تمام‌شده فروش", ["OPERATING_EXPENSE"]="هزینه‌های عملیاتی",
            ["OTHER_REVENUE"]="سایر درآمدها", ["OTHER_EXPENSE"]="سایر هزینه‌ها", ["TAX"]="مالیات"
        }).DefaultView;
        Summary1Label.Text = "سود ناخالص"; Summary1.Text = Money(current, "grossProfit");
        Summary2Label.Text = "سود عملیاتی"; Summary2.Text = Money(current, "operatingProfit");
        Summary3Label.Text = "سود قبل از مالیات"; Summary3.Text = Money(current, "profitBeforeTax");
        Summary4Label.Text = "سود خالص"; Summary4.Text = Money(current, "netProfit");
    }

    private void ShowBalanceSheet(JsonElement root)
    {
        var current = root.GetProperty("current");
        ReportGrid.ItemsSource = SectionTable(current.GetProperty("sections"), new Dictionary<string, string>
        {
            ["CURRENT_ASSET"]="دارایی‌های جاری", ["NONCURRENT_ASSET"]="دارایی‌های غیرجاری", ["CURRENT_LIABILITY"]="بدهی‌های جاری",
            ["NONCURRENT_LIABILITY"]="بدهی‌های غیرجاری", ["EQUITY"]="حقوق مالکانه"
        }).DefaultView;
        Summary1Label.Text = "جمع دارایی‌ها"; Summary1.Text = Money(current, "totalAssets");
        Summary2Label.Text = "جمع بدهی‌ها"; Summary2.Text = Money(current, "totalLiabilities");
        Summary3Label.Text = "حقوق مالکانه"; Summary3.Text = Money(current, "totalEquity");
        Summary4Label.Text = "اختلاف تراز"; Summary4.Text = Money(current, "balanceDifference");
    }

    private void ShowCashFlow(JsonElement root)
    {
        var rows = JsonTable.ExtractRows(root, "lines").ToList();
        if (rows.Count > 0) ReportGrid.ItemsSource = JsonTable.ToDataTable(rows).DefaultView;
        else
        {
            var table = new DataTable(); table.Columns.Add("فعالیت"); table.Columns.Add("مبلغ");
            table.Rows.Add("عملیاتی", Money(root, "operating")); table.Rows.Add("سرمایه‌گذاری", Money(root, "investing")); table.Rows.Add("تأمین مالی", Money(root, "financing"));
            ReportGrid.ItemsSource = table.DefaultView;
        }
        Summary1Label.Text = "عملیاتی"; Summary1.Text = Money(root, "operating");
        Summary2Label.Text = "سرمایه‌گذاری"; Summary2.Text = Money(root, "investing");
        Summary3Label.Text = "تأمین مالی"; Summary3.Text = Money(root, "financing");
        Summary4Label.Text = "خالص تغییر وجه نقد"; Summary4.Text = Money(root, "netCashChange");
    }

    private static DataTable SectionTable(JsonElement sections, IReadOnlyDictionary<string,string> labels)
    {
        var table = new DataTable();
        table.Columns.Add("شرح"); table.Columns.Add("مبلغ");
        foreach (var prop in sections.EnumerateObject())
            table.Rows.Add(labels.TryGetValue(prop.Name, out var title) ? title : prop.Name, Format(ElementDecimal(prop.Value)));
        return table;
    }

    private void ReportGrid_AutoGeneratingColumn(object? sender, DataGridAutoGeneratingColumnEventArgs e)
    {
        var map = new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase)
        {
            ["code"]="کد حساب", ["title"]="عنوان حساب", ["debit"]="بدهکار", ["credit"]="بستانکار", ["balance"]="مانده",
            ["entryNo"]="شماره سند", ["date"]="تاریخ", ["activity"]="فعالیت", ["amount"]="مبلغ", ["sourceType"]="منبع",
            ["accountType"]="نوع حساب", ["nature"]="ماهیت", ["levelNo"]="سطح"
        };
        if (map.TryGetValue(e.PropertyName, out var title)) e.Column.Header = title;
        e.Column.MinWidth = 110;
    }

    private void ResetSummary()
    {
        Summary1.Text = Summary2.Text = Summary3.Text = Summary4.Text = "—";
    }

    private static decimal GetDecimal(JsonElement root, string name) => root.TryGetProperty(name, out var e) ? ElementDecimal(e) : 0;
    private static decimal ElementDecimal(JsonElement e)
    {
        if (e.ValueKind == JsonValueKind.Number && e.TryGetDecimal(out var d)) return d;
        return decimal.TryParse(e.ToString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var x) ? x : 0;
    }
    private static string Money(JsonElement root, string name) => Format(GetDecimal(root, name));
    private static string Format(decimal value) => value.ToString("N0", CultureInfo.InvariantCulture);
}
