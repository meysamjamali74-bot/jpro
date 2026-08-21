using System.Windows;

namespace Tarazpad.Desktop;

public partial class App : Application
{
    public static Services.TarazpadApiClient Api { get; } = new();
}
