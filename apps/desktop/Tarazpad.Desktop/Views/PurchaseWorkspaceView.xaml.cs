using System.Data;
using System.Globalization;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Tarazpad.Desktop.Infrastructure;

namespace Tarazpad.Desktop.Views;

public partial class PurchaseWorkspaceView : UserControl
{
    private DataTable _table = new();
    private readonly DataModuleView? _receiptView;

    public PurchaseWorkspaceView()
    {
        InitializeComponent();
        var receiptDefinition = NativeModuleOverrides.Get("goods-receipts");
        if (receiptDefinition is not null)
        {
            _receiptView = new DataModuleView(receiptDefinition);
            ReceiptHost.Content = _receiptView;
        }
        Loaded += async (_, _) => await RefreshAsync();
    }

    public async Task RefreshAsync()
    {
        LoadingPanel.Visibility = Visibility.Visible;
        try
        {
            var query = new List<string>();
            AddQuery(query, "q", SearchBox.Text.Trim());
            AddQuery(query, "status", SelectedTag(StatusBox));
            AddQuery(query, "classification", SelectedTag(ClassificationBox));
            if (!string.IsNullOrWhiteSpace(FromBox.Text)) AddQuery(query, "dateFrom", PersianDate.ToIso(FromBox.Text));
            if (!string.IsNullOrWhiteSpace(ToBox.Text)) AddQuery(query, "dateTo", PersianDate.ToIso(ToBox.Text));
            var root = await App.Api.GetJsonAsync("api/native/purchase-invoices" + (query.Count > 0 ? "?" + string.Join("&", query) : string.Empty));
            _table = JsonTable.ToDataTable(JsonTable.ExtractRows(root, "rows"));
            Grid.ItemsSource = _table.DefaultView;
            if (root.TryGetProperty("summary", out var summary))
            {
                CountKpi.Text = GetNumber(summary, "count").ToString("N0");
                NetKpi.Text = GetNumber(summary, "net").ToString("N0");
                OutstandingKpi.Text = GetNumber(summary, "outstanding").ToString("N0");
                ExceptionKpi.Text = GetNumber(summary, "exceptions").ToString("N0");
            }
            StatusText.Text = $"{_table.Rows.Count:N0} فاکتور خرید • آخرین بروزرسانی {PersianDate.Today()} - {DateTime.Now:HH:mm}";
            if (_receiptView is not null) await _receiptView.RefreshAsync();
        }
        catch (Exception ex)
        {
            StatusText.Text = ex.Message;
        }
        finally { LoadingPanel.Visibility = Visibility.Collapsed; }
    }

    private async void New_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new PurchaseInvoiceEditorWindow { Owner = Window.GetWindow(this) };
        if (dialog.ShowDialog() == true) await RefreshAsync();
    }

    private async void Refresh_Click(object sender, RoutedEventArgs e) => await RefreshAsync();
    private async void Filter_Click(object sender, RoutedEventArgs e) => await RefreshAsync();
    private async void SearchBox_KeyDown(object sender, KeyEventArgs e) { if (e.Key == Key.Enter) await RefreshAsync(); }
    private void Grid_MouseDoubleClick(object sender, MouseButtonEventArgs e) => ShowDetails();
    private void Details_Click(object sender, RoutedEventArgs e) => ShowDetails();

    private void ShowDetails()
    {
        var id = SelectedLong("id");
        if (id <= 0) { MessageBox.Show("یک فاکتور خرید را انتخاب کنید.", "ترازپاد", MessageBoxButton.OK, MessageBoxImage.Information); return; }
        new InvoiceDetailWindow("purchase", id) { Owner = Window.GetWindow(this) }.ShowDialog();
    }

    private async void Match_Click(object sender, RoutedEventArgs e)
    {
        var id = SelectedLong("id");
        if (id <= 0) { MessageBox.Show("یک فاکتور خرید را انتخاب کنید.", "ترازپاد", MessageBoxButton.OK, MessageBoxImage.Information); return; }
        try
        {
            var result = await App.Api.SendJsonAsync(HttpMethod.Post, $"api/iran/purchase-invoices/{id}/match", new { priceTolerancePct = 1m, qtyTolerance = 0m });
            var status = DocumentJson.String(result, "status");
            var exceptions = DocumentJson.Long(result, "exceptions");
            var high = DocumentJson.Long(result, "highExceptions");
            MessageBox.Show($"نتیجه تطبیق: {UiText.Display(status)}\nتعداد مغایرت: {exceptions:N0}\nمغایرت بااهمیت: {high:N0}", "تطبیق سه‌جانبه", MessageBoxButton.OK, high > 0 ? MessageBoxImage.Warning : MessageBoxImage.Information);
            await RefreshAsync();
        }
        catch (Exception ex) { MessageBox.Show(ex.Message, "تطبیق ناموفق", MessageBoxButton.OK, MessageBoxImage.Error); }
    }

    private async void Post_Click(object sender, RoutedEventArgs e)
    {
        var id = SelectedLong("id");
        if (id <= 0) { MessageBox.Show("یک فاکتور خرید را انتخاب کنید.", "ترازپاد", MessageBoxButton.OK, MessageBoxImage.Information); return; }
        if (MessageBox.Show("فاکتور خرید انتخاب‌شده ثبت قطعی شود؟ فقط فاکتور تأییدشده و بدون مغایرت بااهمیت قابل ثبت است.", "ثبت قطعی خرید", MessageBoxButton.YesNo, MessageBoxImage.Warning) != MessageBoxResult.Yes) return;
        try
        {
            var result = await App.Api.SendJsonAsync(HttpMethod.Post, $"api/iran/purchase-invoices/{id}/post", new { });
            var journalId = DocumentJson.Long(result, "journalEntryId");
            MessageBox.Show($"فاکتور خرید با موفقیت ثبت شد. شناسه سند حسابداری: {journalId:N0}", "ترازپاد", MessageBoxButton.OK, MessageBoxImage.Information);
            await RefreshAsync();
        }
        catch (Exception ex) { MessageBox.Show(ex.Message, "ثبت قطعی ناموفق", MessageBoxButton.OK, MessageBoxImage.Error); }
    }

    private long SelectedLong(string column)
    {
        if (Grid.SelectedItem is not DataRowView row || !row.DataView.Table.Columns.Contains(column)) return 0;
        return long.TryParse(Convert.ToString(row[column], CultureInfo.InvariantCulture), out var value) ? value : 0;
    }
    private static string SelectedTag(ComboBox box) => (box.SelectedItem as ComboBoxItem)?.Tag?.ToString() ?? string.Empty;
    private static void AddQuery(List<string> query, string key, string value) { if (!string.IsNullOrWhiteSpace(value)) query.Add($"{key}={Uri.EscapeDataString(value)}"); }
    private static decimal GetNumber(JsonElement root, string key) => root.TryGetProperty(key, out var value) && value.TryGetDecimal(out var number) ? number : 0;
}
