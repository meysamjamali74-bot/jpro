using System.Globalization;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using Tarazpad.Desktop.Infrastructure;

namespace Tarazpad.Desktop.Views;

public partial class RecordEditorWindow : Window
{
    private sealed record LookupOption(string Value, string Text);
    private sealed record SelectOption(string Value, string Text);

    private readonly ModuleDefinition _module;
    private readonly Dictionary<FieldDefinition, Control> _controls = new();

    public RecordEditorWindow(ModuleDefinition module)
    {
        InitializeComponent();
        _module = module;
        Title = $"ترازپاد - ثبت {_module.Title}";
        TitleText.Text = $"ثبت {_module.Title}";
        SubtitleText.Text = "فیلدهای الزامی با * مشخص شده‌اند. تاریخ‌ها به‌صورت شمسی وارد می‌شوند.";
        BuildFields();
        Loaded += async (_, _) => await LoadLookupsAsync();
    }

    private void BuildFields()
    {
        foreach (var field in _module.CreateFields ?? Array.Empty<FieldDefinition>())
        {
            FieldsPanel.Children.Add(new TextBlock
            {
                Text = field.Required ? $"{field.Label} *" : field.Label,
                FontWeight = FontWeights.SemiBold,
                Foreground = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(68, 81, 102)),
                Margin = new Thickness(0, _controls.Count == 0 ? 0 : 14, 0, 6)
            });

            Control control = field.Type switch
            {
                "select" => BuildSelect(field),
                "lookup" => BuildLookup(),
                "multiline" => new TextBox
                {
                    Height = 82, TextWrapping = TextWrapping.Wrap, AcceptsReturn = true,
                    VerticalScrollBarVisibility = ScrollBarVisibility.Auto, Text = field.DefaultValue ?? string.Empty
                },
                _ => BuildText(field)
            };

            FieldsPanel.Children.Add(control);
            if (field.Type == "jalali-date")
                FieldsPanel.Children.Add(new TextBlock { Text = "نمونه: 1405/05/30", Foreground = System.Windows.Media.Brushes.SlateGray, FontSize = 10, Margin = new Thickness(0, 4, 0, 0) });
            _controls[field] = control;
        }
    }

    private static ComboBox BuildSelect(FieldDefinition field)
    {
        var options = (field.Options ?? Array.Empty<string>()).Select(x => new SelectOption(x, UiText.Display(x))).ToList();
        var combo = new ComboBox
        {
            Height = 38,
            Padding = new Thickness(7),
            ItemsSource = options,
            DisplayMemberPath = nameof(SelectOption.Text)
        };
        combo.SelectedItem = options.FirstOrDefault(x => string.Equals(x.Value, field.DefaultValue, StringComparison.OrdinalIgnoreCase)) ?? options.FirstOrDefault();
        return combo;
    }

    private static ComboBox BuildLookup() => new()
    {
        Height = 38,
        Padding = new Thickness(7),
        IsTextSearchEnabled = true,
        IsEditable = true,
        StaysOpenOnEdit = true,
        DisplayMemberPath = nameof(LookupOption.Text),
        IsEnabled = false,
        Text = "در حال دریافت فهرست..."
    };

    private static TextBox BuildText(FieldDefinition field)
    {
        var value = field.DefaultValue switch
        {
            "TODAY" when field.Type == "jalali-date" => PersianDate.Today(),
            _ => field.DefaultValue ?? string.Empty
        };
        return new TextBox
        {
            Height = 38,
            Text = value,
            FlowDirection = field.Type is "number" or "jalali-date" ? FlowDirection.LeftToRight : FlowDirection.RightToLeft
        };
    }

    private async Task LoadLookupsAsync()
    {
        foreach (var pair in _controls.Where(x => x.Key.Type == "lookup"))
        {
            var field = pair.Key;
            var combo = (ComboBox)pair.Value;
            try
            {
                if (string.IsNullOrWhiteSpace(field.LookupEndpoint)) throw new InvalidOperationException("منبع فهرست تعریف نشده است.");
                var json = await App.Api.GetJsonAsync(field.LookupEndpoint!);
                var rows = ExtractRows(json);
                var options = new List<LookupOption>();
                foreach (var row in rows)
                {
                    if (row.ValueKind != JsonValueKind.Object || !row.TryGetProperty(field.LookupValueKey, out var value)) continue;
                    var display = row.TryGetProperty(field.LookupDisplayKey, out var d) ? JsonText(d) : JsonText(value);
                    if (field.Key == "bankAccountId")
                    {
                        var bank = row.TryGetProperty("bank_name", out var bn) ? JsonText(bn) : string.Empty;
                        var account = row.TryGetProperty("account_title", out var at) ? JsonText(at) : display;
                        display = string.IsNullOrWhiteSpace(bank) ? account : $"{bank} - {account}";
                    }
                    else if (field.Key.EndsWith("partyId", StringComparison.OrdinalIgnoreCase))
                    {
                        var code = row.TryGetProperty("code", out var c) ? JsonText(c) : string.Empty;
                        if (!string.IsNullOrWhiteSpace(code)) display = $"{display} - {code}";
                    }
                    options.Add(new LookupOption(JsonText(value), display));
                }
                combo.ItemsSource = options;
                combo.IsEnabled = true;
                combo.Text = string.Empty;
            }
            catch (Exception ex)
            {
                combo.ItemsSource = Array.Empty<LookupOption>();
                combo.IsEnabled = false;
                combo.Text = "خطا در دریافت فهرست";
                ErrorText.Text = ex.Message;
            }
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
                object? typedValue;
                string raw;

                if (field.Type == "lookup")
                {
                    var combo = (ComboBox)pair.Value;
                    var selected = combo.SelectedItem as LookupOption;
                    raw = selected?.Value ?? string.Empty;
                    typedValue = long.TryParse(raw, out var id) ? id : raw;
                }
                else
                {
                    raw = pair.Value switch
                    {
                        TextBox tb => tb.Text.Trim(),
                        ComboBox { SelectedItem: SelectOption option } => option.Value,
                        ComboBox cb => cb.SelectedItem?.ToString()?.Trim() ?? string.Empty,
                        _ => string.Empty
                    };
                    typedValue = raw;
                }

                if (field.Required && string.IsNullOrWhiteSpace(raw))
                    throw new InvalidOperationException($"فیلد «{field.Label}» الزامی است.");

                if (string.IsNullOrWhiteSpace(raw))
                {
                    payload[field.Key] = null;
                    continue;
                }

                if (field.Type == "number")
                {
                    raw = PersianDate.ToLatinDigits(raw).Replace(",", string.Empty);
                    if (!decimal.TryParse(raw, NumberStyles.Any, CultureInfo.InvariantCulture, out var number))
                        throw new InvalidOperationException($"مقدار «{field.Label}» عدد معتبر نیست.");
                    typedValue = number;
                }
                else if (field.Type == "jalali-date")
                {
                    typedValue = PersianDate.ToIso(raw);
                }

                payload[field.Key] = typedValue;
            }

            NormalizeBusinessPayload(payload);
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

    private void NormalizeBusinessPayload(Dictionary<string, object?> payload)
    {
        if (_module.Key == "parties")
        {
            var role = payload.TryGetValue("role", out var r) ? Convert.ToString(r) : "CUSTOMER";
            payload.Remove("role");
            payload["roles"] = new[] { string.IsNullOrWhiteSpace(role) ? "CUSTOMER" : role! };
        }

        if (_module.Key is "treasury-receipts" or "treasury-payments")
        {
            var method = Convert.ToString(payload.GetValueOrDefault("method"))?.ToUpperInvariant() ?? string.Empty;
            if (method is "BANK" or "TRANSFER" && payload.GetValueOrDefault("bankAccountId") is null)
                throw new InvalidOperationException("برای دریافت/پرداخت بانکی، انتخاب حساب بانکی الزامی است.");
            if (method == "CHEQUE")
            {
                if (string.IsNullOrWhiteSpace(Convert.ToString(payload.GetValueOrDefault("chequeNo"))))
                    throw new InvalidOperationException("برای عملیات چکی، شماره چک الزامی است.");
                if (payload.GetValueOrDefault("dueDate") is null)
                    throw new InvalidOperationException("برای عملیات چکی، تاریخ سررسید الزامی است.");
            }
            payload["idempotencyKey"] = Guid.NewGuid().ToString("N");
        }
    }

    private void Cancel_Click(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
        Close();
    }

    private static IEnumerable<JsonElement> ExtractRows(JsonElement root)
    {
        if (root.ValueKind == JsonValueKind.Array) return root.EnumerateArray().Select(x => x.Clone()).ToArray();
        if (root.ValueKind == JsonValueKind.Object)
        {
            foreach (var key in new[] { "rows", "items", "data", "results" })
                if (root.TryGetProperty(key, out var arr) && arr.ValueKind == JsonValueKind.Array)
                    return arr.EnumerateArray().Select(x => x.Clone()).ToArray();
        }
        return Array.Empty<JsonElement>();
    }

    private static string JsonText(JsonElement value) => value.ValueKind == JsonValueKind.String ? value.GetString() ?? string.Empty : value.GetRawText().Trim('"');
}
