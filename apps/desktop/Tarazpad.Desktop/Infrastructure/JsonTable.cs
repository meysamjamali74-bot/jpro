using System.Data;
using System.Text.Json;

namespace Tarazpad.Desktop.Infrastructure;

public static class JsonTable
{
    public static IEnumerable<JsonElement> ExtractRows(JsonElement root, params string[] preferredKeys)
    {
        if (root.ValueKind == JsonValueKind.Array) return root.EnumerateArray().Select(x => x.Clone()).ToArray();
        if (root.ValueKind != JsonValueKind.Object) return Array.Empty<JsonElement>();
        foreach (var key in preferredKeys.Concat(new[] { "rows", "items", "data", "results" }).Distinct())
            if (root.TryGetProperty(key, out var arr) && arr.ValueKind == JsonValueKind.Array)
                return arr.EnumerateArray().Select(x => x.Clone()).ToArray();
        return new[] { root.Clone() };
    }

    public static DataTable ToDataTable(IEnumerable<JsonElement> source)
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
                row[prop.Name] = UiText.Display(prop.Name, prop.Value);
            }
            table.Rows.Add(row);
        }
        return table;
    }

    public static string Text(JsonElement value)
    {
        var raw = value.ValueKind switch
        {
            JsonValueKind.Null => string.Empty,
            JsonValueKind.True => "بله",
            JsonValueKind.False => "خیر",
            JsonValueKind.String => value.GetString() ?? string.Empty,
            _ => value.GetRawText()
        };
        return UiText.Display(raw);
    }
}
