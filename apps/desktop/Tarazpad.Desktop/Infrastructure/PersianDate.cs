using System.Globalization;

namespace Tarazpad.Desktop.Infrastructure;

public static class PersianDate
{
    private static readonly PersianCalendar Calendar = new();

    public static string Today() => FromGregorian(DateTime.Today);

    public static string FromGregorian(DateTime date)
        => $"{Calendar.GetYear(date):0000}/{Calendar.GetMonth(date):00}/{Calendar.GetDayOfMonth(date):00}";

    public static bool TryToGregorian(string? value, out DateTime date)
    {
        date = default;
        if (string.IsNullOrWhiteSpace(value)) return false;
        var normalized = ToLatinDigits(value.Trim()).Replace('-', '/').Replace('.', '/');
        var parts = normalized.Split('/', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (parts.Length != 3 || !int.TryParse(parts[0], out var y) || !int.TryParse(parts[1], out var m) || !int.TryParse(parts[2], out var d)) return false;
        try
        {
            date = Calendar.ToDateTime(y, m, d, 0, 0, 0, 0);
            return true;
        }
        catch { return false; }
    }

    public static string ToIso(string value)
    {
        if (!TryToGregorian(value, out var date)) throw new FormatException("تاریخ شمسی معتبر نیست. نمونه: 1405/05/30");
        return date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
    }

    public static string ToLatinDigits(string input)
    {
        if (string.IsNullOrEmpty(input)) return input;
        var chars = input.ToCharArray();
        for (var i = 0; i < chars.Length; i++)
        {
            chars[i] = chars[i] switch
            {
                '۰' => '0', '۱' => '1', '۲' => '2', '۳' => '3', '۴' => '4',
                '۵' => '5', '۶' => '6', '۷' => '7', '۸' => '8', '۹' => '9',
                '٠' => '0', '١' => '1', '٢' => '2', '٣' => '3', '٤' => '4',
                '٥' => '5', '٦' => '6', '٧' => '7', '٨' => '8', '٩' => '9',
                _ => chars[i]
            };
        }
        return new string(chars);
    }
}
