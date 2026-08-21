using System.Windows.Controls;
using Tarazpad.Desktop.Infrastructure;

namespace Tarazpad.Desktop.Views;

public partial class TabbedModuleView : UserControl
{
    private readonly List<DataModuleView> _views = new();

    public TabbedModuleView(IEnumerable<ModuleDefinition> definitions)
    {
        InitializeComponent();
        foreach (var definition in definitions)
        {
            var view = new DataModuleView(definition);
            _views.Add(view);
            Tabs.Items.Add(new TabItem { Header = definition.Title, Content = view });
        }
    }

    public async Task RefreshAsync()
    {
        if (Tabs.SelectedItem is TabItem { Content: DataModuleView view }) await view.RefreshAsync();
    }
}
