using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using Tarazpad.Desktop.Infrastructure;

namespace Tarazpad.Desktop.Views;

public partial class TaxCenterView : UserControl
{
    public TaxCenterView()
    {
        InitializeComponent();
        Loaded += async (_, _) => await RefreshAsync();
    }

    public async Task RefreshAsync()
    {
        ProfileStatus.Text = "در حال دریافت اطلاعات...";
        try
        {
            var profileTask = App.Api.GetJsonAsync("api/iran/tax/profile");
            var ratesTask = App.Api.GetJsonAsync("api/iran/tax/rates");
            await Task.WhenAll(profileTask, ratesTask);
            BindProfile(profileTask.Result);
            RatesGrid.ItemsSource = JsonTable.ToDataTable(JsonTable.ExtractRows(ratesTask.Result)).DefaultView;
            ProfileStatus.Foreground = System.Windows.Media.Brushes.SeaGreen;
            ProfileStatus.Text = "اطلاعات مالیاتی از سرور داخلی دریافت شد.";
        }
        catch (Exception ex)
        {
            ProfileStatus.Foreground = System.Windows.Media.Brushes.IndianRed;
            ProfileStatus.Text = ex.Message;
        }
    }

    private void BindProfile(JsonElement p)
    {
        MemoryBox.Text = Get(p, "taxpayer_memory_id");
        EconomicBox.Text = Get(p, "economic_code");
        NationalBox.Text = Get(p, "national_id");
        PostalBox.Text = Get(p, "postal_code");
        TerminalBox.Text = Get(p, "tax_terminal_id");
        AddressBox.Text = Get(p, "address");
        var type = Get(p, "default_invoice_type");
        InvoiceTypeBox.SelectedIndex = type == "TYPE_2" ? 1 : 0;
        EnabledBox.IsChecked = Get(p, "taxpayer_system_enabled") is "1" or "true" or "True";
    }

    private async void SaveButton_Click(object sender, RoutedEventArgs e)
    {
        SaveButton.IsEnabled = false;
        try
        {
            if (string.IsNullOrWhiteSpace(PostalBox.Text) && EnabledBox.IsChecked == true)
                throw new InvalidOperationException("برای فعال‌سازی سامانه مؤدیان، کدپستی شرکت را تکمیل کنید.");
            if (string.IsNullOrWhiteSpace(EconomicBox.Text) && string.IsNullOrWhiteSpace(NationalBox.Text) && EnabledBox.IsChecked == true)
                throw new InvalidOperationException("برای صورتحساب رسمی، کد اقتصادی یا شناسه ملی شرکت الزامی است.");

            var type = (InvoiceTypeBox.SelectedItem as ComboBoxItem)?.Content?.ToString() ?? "TYPE_1";
            await App.Api.SendJsonAsync(HttpMethod.Put, "api/iran/tax/profile", new
            {
                taxpayerMemoryId = MemoryBox.Text.Trim(), economicCode = EconomicBox.Text.Trim(), nationalId = NationalBox.Text.Trim(),
                postalCode = PostalBox.Text.Trim(), address = AddressBox.Text.Trim(), taxTerminalId = TerminalBox.Text.Trim(),
                defaultInvoiceType = type, defaultInvoicePattern = "SALE", taxpayerSystemEnabled = EnabledBox.IsChecked == true
            });
            ProfileStatus.Foreground = System.Windows.Media.Brushes.SeaGreen;
            ProfileStatus.Text = "پروفایل مالیاتی ذخیره شد.";
        }
        catch (Exception ex)
        {
            ProfileStatus.Foreground = System.Windows.Media.Brushes.IndianRed;
            ProfileStatus.Text = ex.Message;
        }
        finally { SaveButton.IsEnabled = true; }
    }

    private void RatesGrid_AutoGeneratingColumn(object? sender, DataGridAutoGeneratingColumnEventArgs e)
    {
        var map = new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase)
        {
            ["tax_kind"]="نوع مالیات", ["tax_code"]="کد", ["rate"]="نرخ", ["effective_from"]="از تاریخ",
            ["effective_to"]="تا تاریخ", ["is_active"]="فعال", ["description"]="شرح"
        };
        if (map.TryGetValue(e.PropertyName, out var title)) e.Column.Header = title;
        e.Column.MinWidth = 95;
    }

    private static string Get(JsonElement p, string name)
    {
        if (p.ValueKind != JsonValueKind.Object || !p.TryGetProperty(name, out var v) || v.ValueKind == JsonValueKind.Null) return string.Empty;
        return JsonTable.Text(v);
    }
}
