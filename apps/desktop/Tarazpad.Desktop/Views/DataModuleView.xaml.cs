using System.Data;
using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Microsoft.Win32;
using Tarazpad.Desktop.Infrastructure;

namespace Tarazpad.Desktop.Views;

public partial class DataModuleView : UserControl
{
    public ModuleDefinition Definition { get; }
    private DataTable _table = new();

    public DataModuleView(ModuleDefinition definition)
    {
        InitializeComponent();
        Definition = definition;
        HeadingText.Text = definition.Title;
        DescriptionText.Text = definition.Subtitle;
        EmptyText.Text = definition.EmptyMessage;
        SearchBox.Visibility = definition.SupportsSearch ? Visibility.Visible : Visibility.Collapsed;
        SearchButton.Visibility = definition.SupportsSearch ? Visibility.Visible : Visibility.Collapsed;
        AddButton.Visibility = string.IsNullOrWhiteSpace(definition.CreateEndpoint) ? Visibility.Collapsed : Visibility.Visible;
        Loaded += async (_, _) => await RefreshAsync();
    }

    public async Task RefreshAsync()
    {
        SetLoading(true);
        try
        {
            var endpoint = Definition.Endpoint;
            if (Definition.SupportsSearch && !string.IsNullOrWhiteSpace(SearchBox.Text))
                endpoint += (endpoint.Contains('?') ? "&" : "?") + "q=" + Uri.EscapeDataString(SearchBox.Text.Trim());

            var json = await App.Api.GetJsonAsync(endpoint);
            _table = ToDataTable(ExtractRows(json));
            Grid.ItemsSource = _table.DefaultView;
            CountText.Text = $"{_table.Rows.Count:N0} رکورد";
            EmptyPanel.Visibility = _table.Rows.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
            FooterText.Text = $"آخرین بروزرسانی: {DateTime.Now:yyyy/MM/dd HH:mm:ss}";
        }
        catch (Exception ex)
        {
            _table = new DataTable();
            Grid.ItemsSource = _table.DefaultView;
            EmptyPanel.Visibility = Visibility.Visible;
            EmptyText.Text = "دریافت اطلاعات ناموفق بود";
            FooterText.Text = ex.Message;
        }
        finally
        {
            SetLoading(false);
        }
    }

    private async void Add_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new RecordEditorWindow(Definition) { Owner = Window.GetWindow(this) };
        if (dialog.ShowDialog() == true) await RefreshAsync();
    }

    private async void SearchButton_Click(object sender, RoutedEventArgs e) => await RefreshAsync();
    private async void Refresh_Click(object sender, RoutedEventArgs e) => await RefreshAsync();

    private async void SearchBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter) await RefreshAsync();
    }

    private void Grid_AutoGeneratingColumn(object? sender, DataGridAutoGeneratingColumnEventArgs e)
    {
        if (Definition.ColumnTitles?.TryGetValue(e.PropertyName, out var title) == true) e.Column.Header = title;
        e.Column.MinWidth = 90;
        e.Column.Width = new DataGridLength(1, DataGridLengthUnitType.Auto);
    }

    private void Grid_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        SelectionText.Text = Grid.SelectedItem == null ? string.Empty : "۱ ردیف انتخاب شده";
    }

    private void Export_Click(object sender, RoutedEventArgs e)
    {
        if (_table.Columns.Count == 0)
        {
            MessageBox.Show("داده‌ای برای خروجی وجود ندارد.", "ترازپاد", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        var dialog = new SaveFileDialog
        {
            Filter = "CSV UTF-8 (*.csv)|*.csv",
            FileName = $"Tarazpad-{Definition.Key}-{DateTime.Now:yyyyMMdd-HHmm}.csv"
        };
        if (dialog.ShowDialog() != true) return;

        var sb = new StringBuilder();
        sb.AppendLine(string.Join(",", _table.Columns.Cast<DataColumn>().Select(c => Csv(c.ColumnName))));
        foreach (DataRow row in _table.Rows)
            sb.AppendLine(string.Join(",", _table.Columns.Cast<DataColumn>().Select(c => Csv(Convert.ToString(row[c], CultureInfo.InvariantCulture) ?? string.Empty))));
        File.WriteAllText(dialog.FileName, "\uFEFF" + sb, new UTF8Encoding(false));
        FooterText.Text = $"خروجی ذخیره شد: {dialog.FileName}";
    }

    private void SetLoading(bool loading)
    {
        LoadingPanel.Visibility = loading ? Visibility.Visible : Visibility.Collapsed;
        SearchButton.IsEnabled = !loading;
        AddButton.IsEnabled = !loading;
        Grid.IsEnabled = !loading;
    }

    private static IEnumerable<JsonElement> ExtractRows(JsonElement root)
    {
        if (root.ValueKind == JsonValueKind.Array) return root.EnumerateArray().Select(x => x.Clone()).ToArray();
        if (root.ValueKind == JsonValueKind.Object)
        {
            foreach (var key in new[] { "rows", "items", "data", "customers", "results" })
                if (root.TryGetProperty(key, out var value) && value.ValueKind == JsonValueKind.Array)
                    return value.EnumerateArray().Select(x => x.Clone()).ToArray();
            return new[] { root.Clone() };
        }
        return Array.Empty<JsonElement>();
    }

    private static DataTable ToDataTable(IEnumerable<JsonElement> source)
    {
        var rows = source.Where(x => x.ValueKind == JsonValueKind.Object).ToList();
        var table = new DataTable();
        var keys = rows.SelectMany(r => r.EnumerateObject())
            .Where(p => p.Value.ValueKind is not JsonValueKind.Object and not JsonValueKind.Array)
            .Select(p => p.Name)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        foreach (var key in keys) table.Columns.Add(key, typeof(string));
        foreach (var item in rows)
        {
            var row = table.NewRow();
            foreach (var prop in item.EnumerateObject())
            {
                if (!table.Columns.Contains(prop.Name)) continue;
                row[prop.Name] = prop.Value.ValueKind switch
                {
                    JsonValueKind.Null => string.Empty,
                    JsonValueKind.True => "بله",
                    JsonValueKind.False => "خیر",
                    JsonValueKind.String => prop.Value.GetString() ?? string.Empty,
                    _ => prop.Value.GetRawText()
                };
            }
            table.Rows.Add(row);
        }
        return table;
    }

    private static string Csv(string text) => '"' + text.Replace("\"", "\"\"").Replace("\r", " ").Replace("\n", " ") + '"';
}
