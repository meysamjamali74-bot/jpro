using System.Collections.ObjectModel;
using System.Windows;

namespace Tarazpad.Desktop.Views;

public sealed class DashboardWidgetOption
{
    public required string Key { get; init; }
    public required string Title { get; init; }
    public required string Unit { get; init; }
    public bool IsSelected { get; set; }
}

public partial class DashboardCustomizeWindow : Window
{
    public ObservableCollection<DashboardWidgetOption> Options { get; } = new();
    public HashSet<string> SelectedKeys { get; private set; } = new(StringComparer.OrdinalIgnoreCase);

    public DashboardCustomizeWindow(IEnumerable<DashboardWidget> widgets, ISet<string> visible)
    {
        InitializeComponent();
        foreach (var widget in widgets)
            Options.Add(new DashboardWidgetOption
            {
                Key = widget.Key,
                Title = widget.Title,
                Unit = widget.Unit,
                IsSelected = visible.Contains(widget.Key)
            });
        DataContext = this;
    }

    private void SelectAll_Click(object sender, RoutedEventArgs e)
    {
        foreach (var item in Options) item.IsSelected = true;
        RefreshOptions();
    }

    private void ClearAll_Click(object sender, RoutedEventArgs e)
    {
        foreach (var item in Options) item.IsSelected = false;
        RefreshOptions();
    }

    private void RefreshOptions()
    {
        var copy = Options.ToArray();
        Options.Clear();
        foreach (var item in copy) Options.Add(item);
    }

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        SelectedKeys = Options.Where(x => x.IsSelected).Select(x => x.Key).ToHashSet(StringComparer.OrdinalIgnoreCase);
        DialogResult = true;
    }

    private void Cancel_Click(object sender, RoutedEventArgs e) => DialogResult = false;
}
