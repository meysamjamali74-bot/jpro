using System.Globalization;
using System.Text.Json;
using System.Windows.Controls;

namespace Tarazpad.Desktop.Views;

public partial class DashboardView : UserControl
{
    public DashboardView()
    {
        InitializeComponent();
        Loaded += async (_, _) => await RefreshAsync();
    }

    public async Task RefreshAsync()
    {
        try
        {
            var json = await App.Api.GetJsonAsync("api/dashboard/summary");
            SalesTodayText.Text = Money(json, "sales_today");
            SalesMonthText.Text = Money(json, "sales_month");
            ArOpenText.Text = Money(json, "ar_open");
            ArOverdueText.Text = Money(json, "ar_overdue");
            InventoryText.Text = Money(json, "inventory_value");
            CashPositionText.Text = Money(json, "cash_position");
            ReservedText.Text = Number(json, "reserved_qty");
            TasksText.Text = Number(json, "open_tasks");
            TripsText.Text = Number(json, "trips_today");
            TripsRouteText.Text = Number(json, "trips_in_route");
            LastRefreshText.Text = $"آخرین بروزرسانی: {DateTime.Now:yyyy/MM/dd HH:mm:ss}";
            HealthText.Text = "● متصل";
            HealthText.Foreground = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(15, 157, 104));
        }
        catch (Exception ex)
        {
            HealthText.Text = "● خطا در دریافت داده";
            HealthText.Foreground = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(217, 54, 62));
            LastRefreshText.Text = ex.Message;
        }
    }

    private static string Money(JsonElement json, string name)
        => decimal.TryParse(GetRaw(json, name), NumberStyles.Any, CultureInfo.InvariantCulture, out var value)
            ? value.ToString("N0", CultureInfo.InvariantCulture)
            : "0";

    private static string Number(JsonElement json, string name)
        => decimal.TryParse(GetRaw(json, name), NumberStyles.Any, CultureInfo.InvariantCulture, out var value)
            ? value.ToString("N0", CultureInfo.InvariantCulture)
            : "0";

    private static string GetRaw(JsonElement json, string name)
    {
        if (json.ValueKind == JsonValueKind.Object && json.TryGetProperty(name, out var value))
            return value.ValueKind == JsonValueKind.String ? value.GetString() ?? "0" : value.GetRawText();
        return "0";
    }
}
