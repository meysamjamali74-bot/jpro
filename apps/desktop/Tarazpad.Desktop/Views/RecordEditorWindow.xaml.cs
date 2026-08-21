using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using Tarazpad.Desktop.Infrastructure;

namespace Tarazpad.Desktop.Views;

public partial class RecordEditorWindow : Window
{
    private readonly ModuleDefinition _module;
    private readonly Dictionary<FieldDefinition, Control> _controls = new();

    public RecordEditorWindow(ModuleDefinition module)
    {
        InitializeComponent();
        _module = module;
        Title = $"ترازپاد - ثبت {_module.Title}";
        TitleText.Text = $"ثبت {_module.Title}";
        SubtitleText.Text = "فیلدهای الزامی با * مشخص شده‌اند.";
        BuildFields();
    }

    private void BuildFields()
    {
        foreach (var field in _module.CreateFields ?? Array.Empty<FieldDefinition>())
        {
            var label = new TextBlock
            {
                Text = field.Required ? $"{field.Label} *" : field.Label,
                FontWeight = FontWeights.SemiBold,
                Foreground = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(68, 81, 102)),
                Margin = new Thickness(0, _controls.Count == 0 ? 0 : 14, 0, 6)
            };
            FieldsPanel.Children.Add(label);

            Control control;
            if (field.Type == "select")
            {
                var combo = new ComboBox { Height = 38, Padding = new Thickness(7), ItemsSource = field.Options };
                combo.SelectedItem = field.DefaultValue ?? field.Options?.FirstOrDefault();
                control = combo;
            }
            else if (field.Type == "multiline")
            {
                control = new TextBox { Height = 82, TextWrapping = TextWrapping.Wrap, AcceptsReturn = true, VerticalScrollBarVisibility = ScrollBarVisibility.Auto, Text = field.DefaultValue ?? string.Empty };
            }
            else
            {
                var text = new TextBox
                {
                    Height = 38,
                    Text = field.DefaultValue ?? (field.Type == "datetime" ? DateTime.Now.AddDays(1).ToString("yyyy-MM-dd HH:mm", CultureInfo.InvariantCulture) : string.Empty)
                };
                if (field.Type is "number" or "datetime") text.FlowDirection = FlowDirection.LeftToRight;
                control = text;
            }

            FieldsPanel.Children.Add(control);
            _controls[field] = control;
        }
    }

    private async void Save_Click(object sender, RoutedEventArgs e)
    {
        ErrorText.Text = string.Empty;
        SaveButton.IsEnabled = false;
        try
        {
            var payload = new Dictionary<string, object?>();
            foreach (var pair in _controls)
            {
                var field = pair.Key;
                var raw = pair.Value switch
                {
                    TextBox tb => tb.Text.Trim(),
                    ComboBox cb => cb.SelectedItem?.ToString()?.Trim() ?? string.Empty,
                    _ => string.Empty
                };

                if (field.Required && string.IsNullOrWhiteSpace(raw))
                    throw new InvalidOperationException($"فیلد «{field.Label}» الزامی است.");

                if (string.IsNullOrWhiteSpace(raw))
                {
                    payload[field.Key] = null;
                    continue;
                }

                if (field.Type == "number")
                {
                    if (!decimal.TryParse(raw.Replace(",", string.Empty), NumberStyles.Any, CultureInfo.InvariantCulture, out var number))
                        throw new InvalidOperationException($"مقدار «{field.Label}» عدد معتبر نیست.");
                    payload[field.Key] = number;
                }
                else if (field.Type == "datetime")
                {
                    if (!DateTime.TryParse(raw, CultureInfo.InvariantCulture, DateTimeStyles.AssumeLocal, out var dt))
                        throw new InvalidOperationException($"تاریخ «{field.Label}» معتبر نیست. نمونه: 2026-08-21 14:30");
                    payload[field.Key] = dt.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture);
                }
                else
                {
                    payload[field.Key] = raw;
                }
            }

            if (_module.Key == "parties") payload["roles"] = new[] { "CUSTOMER" };
            if (string.IsNullOrWhiteSpace(_module.CreateEndpoint)) throw new InvalidOperationException("ثبت برای این ماژول فعال نیست.");

            await App.Api.SendJsonAsync(HttpMethod.Post, _module.CreateEndpoint!, payload);
            DialogResult = true;
            Close();
        }
        catch (Exception ex)
        {
            ErrorText.Text = ex.Message;
        }
        finally
        {
            SaveButton.IsEnabled = true;
        }
    }

    private void Cancel_Click(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
        Close();
    }
}
