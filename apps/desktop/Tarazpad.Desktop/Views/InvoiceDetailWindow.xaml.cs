using System.Data;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using Tarazpad.Desktop.Infrastructure;

namespace Tarazpad.Desktop.Views;

public partial class InvoiceDetailWindow : Window
{
    private readonly string _kind;
    private readonly long _id;
    private static readonly Dictionary<string, string> Titles = new(StringComparer.OrdinalIgnoreCase)
    {
        ["sku"]="کد کالا", ["product_name"]="کالا / خدمت", ["description"]="شرح", ["unit"]="واحد",
        ["qty"]="مقدار", ["unit_price"]="قیمت واحد", ["discount_amount"]="تخفیف", ["tax_amount"]="مالیات",
        ["other_duties_amount"]="عوارض", ["line_total"]="جمع ردیف", ["vat_status"]="وضعیت مالیات", ["vat_rate"]="نرخ VAT",
        ["gross_profit_amount"]="سود ناخالص", ["severity"]="اهمیت", ["match_type"]="نوع مغایرت", ["message"]="شرح مغایرت",
        ["expected_value"]="مقدار مورد انتظار", ["actual_value"]="مقدار واقعی", ["variance_value"]="مغایرت", ["status"]="وضعیت"
    };

    public InvoiceDetailWindow(string kind, long id)
    {
        InitializeComponent();
        _kind = kind;
        _id = id;
        Loaded += async (_, _) => await LoadAsync();
    }

    private async Task LoadAsync()
    {
        try
        {
            StatusText.Text = "در حال دریافت جزئیات...";
            var root = await App.Api.GetJsonAsync($"api/native/{_kind}-invoices/{_id}");
            var invoice = root.GetProperty("invoice");
            var isSales = _kind.Equals("sales", StringComparison.OrdinalIgnoreCase);
            var number = DocumentJson.String(invoice, "invoice_no");
            var party = DocumentJson.String(invoice, isSales ? "customer" : "supplier");
            var date = invoice.TryGetProperty("invoice_date", out var d) ? UiText.Display("invoice_date", d) : string.Empty;
            var status = invoice.TryGetProperty("status", out var s) ? UiText.Display("status", s) : string.Empty;
            var classification = invoice.TryGetProperty("invoice_classification", out var c) ? UiText.Display("invoice_classification", c) : string.Empty;
            var net = DocumentJson.Decimal(invoice, "net_total");
            var outstanding = DocumentJson.Decimal(invoice, "outstanding_amount");
            HeaderText.Text = $"{(isSales ? "فاکتور فروش" : "فاکتور خرید")} {number}";
            MetaText.Text = $"طرف حساب: {party}   |   تاریخ: {date}   |   نوع: {classification}   |   وضعیت: {status}   |   خالص: {net:N0} ریال   |   مانده: {outstanding:N0} ریال";
            LinesGrid.ItemsSource = JsonTable.ToDataTable(JsonTable.ExtractRows(root, "lines")).DefaultView;

            if (!isSales && root.TryGetProperty("matches", out var matches) && matches.ValueKind == JsonValueKind.Array && matches.GetArrayLength() > 0)
            {
                MatchesGrid.ItemsSource = JsonTable.ToDataTable(JsonTable.ExtractRows(matches)).DefaultView;
                MatchesBorder.Visibility = Visibility.Visible;
            }
            StatusText.Text = "جزئیات از موتور عملیاتی ترازپاد خوانده شد.";
        }
        catch (Exception ex)
        {
            StatusText.Text = ex.Message;
        }
    }

    private void Grid_AutoGeneratingColumn(object? sender, DataGridAutoGeneratingColumnEventArgs e)
    {
        var key = e.PropertyName;
        if (key.Equals("id", StringComparison.OrdinalIgnoreCase) || key.Equals("invoice_id", StringComparison.OrdinalIgnoreCase)
            || key.EndsWith("_id", StringComparison.OrdinalIgnoreCase) || key.Contains("snapshot", StringComparison.OrdinalIgnoreCase)
            || key is "goods_service_id" or "unit_code" or "amount_before_discount" or "amount_after_discount")
        {
            e.Cancel = true;
            return;
        }
        if (Titles.TryGetValue(key, out var title)) e.Column.Header = title;
        e.Column.MinWidth = 80;
        e.Column.Width = new DataGridLength(1, DataGridLengthUnitType.Auto);
    }
}
