using System.Data;
using System.Globalization;
using System.Text;
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
            _table = JsonTable.ToDataTable(JsonTable.ExtractRows(json));
            Grid.ItemsSource = _table.DefaultView;
            CountText.Text = $"{_table.Rows.Count:N0} رکورد";
            EmptyPanel.Visibility = _table.Rows.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
            FooterText.Text = $"آخرین بروزرسانی: {PersianDate.Today()} - {DateTime.Now:HH:mm:ss}";
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
        string? title = null;
        var hasFriendlyTitle = Definition.ColumnTitles is not null && Definition.ColumnTitles.TryGetValue(e.PropertyName, out title);
        if (hasFriendlyTitle && title is not null) e.Column.Header = title;

        if (!hasFriendlyTitle && (e.PropertyName.Equals("id", StringComparison.OrdinalIgnoreCase)
            || e.PropertyName.Equals("company_id", StringComparison.OrdinalIgnoreCase)
            || e.PropertyName.Equals("created_by", StringComparison.OrdinalIgnoreCase)
            || e.PropertyName.Equals("updated_by", StringComparison.OrdinalIgnoreCase)
            || e.PropertyName.EndsWith("_party_id", StringComparison.OrdinalIgnoreCase)
            || e.PropertyName.EndsWith("_user_id", StringComparison.OrdinalIgnoreCase)
            || e.PropertyName.EndsWith("_entry_id", StringComparison.OrdinalIgnoreCase)))
        {
            e.Cancel = true;
            return;
        }

        e.Column.MinWidth = 95;
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
        sb.AppendLine(string.Join(",", _table.Columns.Cast<DataColumn>().Select(c => Csv(FriendlyColumnName(c.ColumnName)))));
        foreach (DataRow row in _table.Rows)
            sb.AppendLine(string.Join(",", _table.Columns.Cast<DataColumn>().Select(c => Csv(Convert.ToString(row[c], CultureInfo.InvariantCulture) ?? string.Empty))));
        File.WriteAllText(dialog.FileName, "\uFEFF" + sb, new UTF8Encoding(false));
        FooterText.Text = $"خروجی ذخیره شد: {dialog.FileName}";
    }

    private string FriendlyColumnName(string name)
        => Definition.ColumnTitles is not null && Definition.ColumnTitles.TryGetValue(name, out var title) ? title : name;

    private void SetLoading(bool loading)
    {
        LoadingPanel.Visibility = loading ? Visibility.Visible : Visibility.Collapsed;
        SearchButton.IsEnabled = !loading;
        AddButton.IsEnabled = !loading;
        Grid.IsEnabled = !loading;
    }

    private static string Csv(string text) => '"' + text.Replace("\"", "\"\"").Replace("\r", " ").Replace("\n", " ") + '"';
}
