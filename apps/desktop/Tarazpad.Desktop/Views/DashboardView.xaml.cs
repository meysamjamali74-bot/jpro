using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Globalization;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using Tarazpad.Desktop.Infrastructure;

namespace Tarazpad.Desktop.Views;

public sealed class DashboardWidget : INotifyPropertyChanged
{
    private string _value = "—";
    public required string Key { get; init; }
    public required string Title { get; init; }
    public required string Unit { get; init; }
    public string Value { get => _value; set { if (_value == value) return; _value = value; OnPropertyChanged(); } }
    public event PropertyChangedEventHandler? PropertyChanged;
    private void OnPropertyChanged([CallerMemberName] string? name = null) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}

public partial class DashboardView : UserControl
{
    private static readonly (string Key, string Title, string Unit)[] Definitions =
    {
        ("sales_today", "فروش امروز", "ریال"),
        ("sales_month", "فروش ماه", "ریال"),
        ("ar_open", "مطالبات باز", "ریال"),
        ("ar_overdue", "مطالبات سررسید گذشته", "ریال"),
        ("inventory_value", "ارزش موجودی", "ریال"),
        ("cash_position", "موقعیت نقدینگی", "ریال"),
        ("reserved_qty", "مقدار رزروشده", "مقدار"),
        ("open_tasks", "وظایف باز", "مورد"),
        ("trips_today", "سفرهای امروز", "سفر"),
        ("trips_in_route", "سفرهای در مسیر", "سفر")
    };

    private readonly Dictionary<string, DashboardWidget> _catalog;
    private readonly HashSet<string> _hidden = new(StringComparer.OrdinalIgnoreCase);
    private Point _dragStart;
    private DashboardWidget? _dragWidget;
    private bool _layoutLoaded;

    public ObservableCollection<DashboardWidget> Widgets { get; } = new();

    public DashboardView()
    {
        InitializeComponent();
        _catalog = Definitions.ToDictionary(x => x.Key, x => new DashboardWidget { Key = x.Key, Title = x.Title, Unit = x.Unit }, StringComparer.OrdinalIgnoreCase);
        DataContext = this;
        foreach (var definition in Definitions) Widgets.Add(_catalog[definition.Key]);
        Loaded += async (_, _) =>
        {
            if (!_layoutLoaded) await LoadLayoutAsync();
            await RefreshAsync();
        };
    }

    private async Task LoadLayoutAsync()
    {
        _layoutLoaded = true;
        try
        {
            var layout = await App.Api.GetJsonAsync("api/dashboard/layout");
            JsonDocument? nestedDocument = null;
            if (layout.ValueKind == JsonValueKind.String && !string.IsNullOrWhiteSpace(layout.GetString()))
            {
                nestedDocument = JsonDocument.Parse(layout.GetString()!);
                layout = nestedDocument.RootElement.Clone();
            }
            try
            {
                if (layout.ValueKind != JsonValueKind.Array) { UpdateEmptyState(); return; }

                var ordered = new List<(string Key, bool Visible, int Order)>();
                var position = 0;
                foreach (var item in layout.EnumerateArray())
                {
                    if (item.ValueKind == JsonValueKind.String)
                    {
                        var key = item.GetString() ?? string.Empty;
                        if (_catalog.ContainsKey(key)) ordered.Add((key, true, position++));
                        continue;
                    }
                    if (item.ValueKind != JsonValueKind.Object) continue;
                    var keyValue = item.TryGetProperty("key", out var keyProp) ? keyProp.GetString() : null;
                    if (string.IsNullOrWhiteSpace(keyValue) || !_catalog.ContainsKey(keyValue)) continue;
                    var visible = !item.TryGetProperty("visible", out var visibleProp) || visibleProp.ValueKind != JsonValueKind.False;
                    var order = item.TryGetProperty("order", out var orderProp) && orderProp.TryGetInt32(out var parsed) ? parsed : position;
                    ordered.Add((keyValue, visible, order));
                    position++;
                }

                if (ordered.Count == 0) { UpdateEmptyState(); return; }
                Widgets.Clear();
                _hidden.Clear();
                var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                foreach (var item in ordered.OrderBy(x => x.Order))
                {
                    seen.Add(item.Key);
                    if (item.Visible) Widgets.Add(_catalog[item.Key]); else _hidden.Add(item.Key);
                }
                foreach (var definition in Definitions)
                    if (!seen.Contains(definition.Key)) Widgets.Add(_catalog[definition.Key]);
                UpdateEmptyState();
            }
            finally
            {
                nestedDocument?.Dispose();
            }
        }
        catch
        {
            // A missing/legacy preference must never make the dashboard unusable.
            UpdateEmptyState();
        }
    }

    public async Task RefreshAsync()
    {
        try
        {
            var json = await App.Api.GetJsonAsync("api/dashboard/summary");
            foreach (var definition in Definitions)
            {
                var widget = _catalog[definition.Key];
                widget.Value = definition.Unit == "ریال" ? Money(json, definition.Key) : Number(json, definition.Key);
            }
            LastRefreshText.Text = $"آخرین بروزرسانی: {PersianDate.Today()}  {DateTime.Now:HH:mm:ss}";
            HealthText.Text = "● متصل";
            HealthText.Foreground = new SolidColorBrush(Color.FromRgb(15, 157, 104));
        }
        catch (Exception ex)
        {
            HealthText.Text = "● خطا در دریافت داده";
            HealthText.Foreground = new SolidColorBrush(Color.FromRgb(217, 54, 62));
            LastRefreshText.Text = ex.Message;
        }
    }

    private async void CustomizeButton_Click(object sender, RoutedEventArgs e)
    {
        var visible = Widgets.Select(x => x.Key).ToHashSet(StringComparer.OrdinalIgnoreCase);
        var window = new DashboardCustomizeWindow(Definitions.Select(x => _catalog[x.Key]), visible)
        {
            Owner = Window.GetWindow(this)
        };
        if (window.ShowDialog() != true) return;

        var selected = window.SelectedKeys;
        var current = Widgets.Select(x => x.Key).ToList();
        Widgets.Clear();
        _hidden.Clear();
        foreach (var key in current)
            if (selected.Contains(key)) Widgets.Add(_catalog[key]);
        foreach (var definition in Definitions)
            if (selected.Contains(definition.Key) && Widgets.All(x => !x.Key.Equals(definition.Key, StringComparison.OrdinalIgnoreCase)))
                Widgets.Add(_catalog[definition.Key]);
        foreach (var definition in Definitions)
            if (!selected.Contains(definition.Key)) _hidden.Add(definition.Key);
        UpdateEmptyState();
        await SaveLayoutAsync();
    }

    private void Widget_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        _dragStart = e.GetPosition(this);
        _dragWidget = (sender as FrameworkElement)?.DataContext as DashboardWidget;
    }

    private void Widget_MouseMove(object sender, MouseEventArgs e)
    {
        if (e.LeftButton != MouseButtonState.Pressed || _dragWidget is null || sender is not DependencyObject source) return;
        var point = e.GetPosition(this);
        if (Math.Abs(point.X - _dragStart.X) < SystemParameters.MinimumHorizontalDragDistance &&
            Math.Abs(point.Y - _dragStart.Y) < SystemParameters.MinimumVerticalDragDistance) return;
        DragDrop.DoDragDrop(source, _dragWidget, DragDropEffects.Move);
    }

    private void Widget_DragEnter(object sender, DragEventArgs e)
    {
        e.Effects = e.Data.GetDataPresent(typeof(DashboardWidget)) ? DragDropEffects.Move : DragDropEffects.None;
        e.Handled = true;
    }

    private async void Widget_Drop(object sender, DragEventArgs e)
    {
        if (e.Data.GetData(typeof(DashboardWidget)) is not DashboardWidget source ||
            (sender as FrameworkElement)?.DataContext is not DashboardWidget target ||
            ReferenceEquals(source, target)) return;
        var from = Widgets.IndexOf(source);
        var to = Widgets.IndexOf(target);
        if (from < 0 || to < 0) return;
        Widgets.Move(from, to);
        _dragWidget = null;
        await SaveLayoutAsync();
    }

    private async Task SaveLayoutAsync()
    {
        try
        {
            var layout = new List<object>();
            var order = 0;
            foreach (var widget in Widgets)
                layout.Add(new { key = widget.Key, visible = true, order = order++ });
            foreach (var definition in Definitions)
                if (_hidden.Contains(definition.Key)) layout.Add(new { key = definition.Key, visible = false, order = order++ });
            await App.Api.SendJsonAsync(HttpMethod.Put, "api/dashboard/layout", layout);
        }
        catch (Exception ex)
        {
            LastRefreshText.Text = $"چیدمان روی سرور ذخیره نشد: {ex.Message}";
        }
    }

    private void UpdateEmptyState() => EmptyDashboard.Visibility = Widgets.Count == 0 ? Visibility.Visible : Visibility.Collapsed;

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
