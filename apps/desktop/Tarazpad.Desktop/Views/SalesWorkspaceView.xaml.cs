using System.Data;
using System.Globalization;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Tarazpad.Desktop.Infrastructure;

namespace Tarazpad.Desktop.Views;

public partial class SalesWorkspaceView : UserControl
{
    private DataTable _table = new();

    public SalesWorkspaceView()
    {
        InitializeComponent();
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
            var endpoint = "api/native/sales-invoices" + (query.Count > 0 ? "?" + string.Join("&", query) : string.Empty);
            var root = await App.Api.GetJsonAsync(endpoint);
            _table = JsonTable.ToDataTable(JsonTable.ExtractRows(root, "rows"));
            Grid.ItemsSource = _table.DefaultView;
            if (root.TryGetProperty("summary", out var summary))
            {
                CountKpi.Text = GetNumber(summary, "count").ToString("N0");
                NetKpi.Text = GetNumber(summary, "net").ToString("N0");
                OutstandingKpi.Text = GetNumber(summary, "outstanding").ToString("N0");
                DraftKpi.Text = GetNumber(summary, "draft").ToString("N0");
            }
            StatusText.Text = $"{_table.Rows.Count:N0} فاکتور • آخرین بروزرسانی {PersianDate.Today()} - {DateTime.Now:HH:mm}";
        }
        catch (Exception ex)
        {
            StatusText.Text = ex.Message;
        }
        finally
        {
            LoadingPanel.Visibility = Visibility.Collapsed;
        }
    }

    private async void New_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new SalesInvoiceEditorWindow { Owner = Window.GetWindow(this) };
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
        if (id <= 0) { MessageBox.Show("یک فاکتور را انتخاب کنید.", "ترازپاد", MessageBoxButton.OK, MessageBoxImage.Information); return; }
        new InvoiceDetailWindow("sales", id) { Owner = Window.GetWindow(this) }.ShowDialog();
    }

    private async void Post_Click(object sender, RoutedEventArgs e)
    {
        var id = SelectedLong("id");
        if (id <= 0) { MessageBox.Show("یک فاکتور را انتخاب کنید.", "ترازپاد", MessageBoxButton.OK, MessageBoxImage.Information); return; }
        if (MessageBox.Show("فاکتور انتخاب‌شده ثبت قطعی شود؟ این عملیات ممکن است طبق سیاست شرکت خروج انبار و سند حسابداری ایجاد کند.", "ثبت قطعی فروش", MessageBoxButton.YesNo, MessageBoxImage.Warning) != MessageBoxResult.Yes) return;
        try
        {
            var warehouseId = SelectedLong("warehouse_id");
            if (warehouseId <= 0) warehouseId = await ChooseWarehouseAsync();
            var payload = warehouseId > 0 ? new { warehouseId } : new { } as object;
            var result = await App.Api.SendJsonAsync(HttpMethod.Post, $"api/iran/sales-invoices/{id}/post", payload);
            var entry = result.TryGetProperty("entryNo", out var no) ? no.ToString() : string.Empty;
            MessageBox.Show(string.IsNullOrWhiteSpace(entry) ? "فاکتور با موفقیت ثبت قطعی شد." : $"فاکتور ثبت شد. شماره سند: {entry}", "ترازپاد", MessageBoxButton.OK, MessageBoxImage.Information);
            await RefreshAsync();
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "ثبت قطعی ناموفق", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private async Task<long> ChooseWarehouseAsync()
    {
        var root = await App.Api.GetJsonAsync("api/native/document-lookups");
        var warehouses = DocumentJson.Warehouses(root);
        if (warehouses.Count == 0) return 0;
        if (warehouses.Count == 1) return warehouses[0].Id;

        var combo = new ComboBox { ItemsSource = warehouses, DisplayMemberPath = "Display", SelectedIndex = 0, Height = 38, Margin = new Thickness(0, 8, 0, 18) };
        var ok = new Button { Content = "انتخاب انبار", Width = 120, Height = 38, IsDefault = true, HorizontalAlignment = HorizontalAlignment.Left };
        var cancel = new Button { Content = "انصراف", Width = 90, Height = 38, IsCancel = true, Margin = new Thickness(8, 0, 0, 0) };
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, FlowDirection = FlowDirection.LeftToRight, HorizontalAlignment = HorizontalAlignment.Left };
        buttons.Children.Add(cancel); buttons.Children.Add(ok);
        var panel = new StackPanel { Margin = new Thickness(22), FlowDirection = FlowDirection.RightToLeft };
        panel.Children.Add(new TextBlock { Text = "انبار خروج را برای ثبت قطعی انتخاب کنید.", FontSize = 13, FontWeight = FontWeights.SemiBold });
        panel.Children.Add(combo); panel.Children.Add(buttons);
        var window = new Window { Title = "انتخاب انبار", Width = 430, SizeToContent = SizeToContent.Height, ResizeMode = ResizeMode.NoResize, WindowStartupLocation = WindowStartupLocation.CenterOwner, Owner = Window.GetWindow(this), Content = panel };
        ok.Click += (_, _) => { window.DialogResult = true; window.Close(); };
        return window.ShowDialog() == true && combo.SelectedItem is WarehouseLookupItem item ? item.Id : 0;
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
