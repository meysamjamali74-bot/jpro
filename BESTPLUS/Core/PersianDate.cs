using System.Globalization;

namespace Bestplus;

public static class PersianDate
{
    private static readonly PersianCalendar Pc = new();

    public static string Format(DateTime date) => $"{Pc.GetYear(date):0000}/{Pc.GetMonth(date):00}/{Pc.GetDayOfMonth(date):00}";

    public static bool TryParse(string? text, out DateTime date)
    {
        date = DateTime.Today;
        if (string.IsNullOrWhiteSpace(text)) return false;
        try
        {
            var p = text.Replace('-', '/').Trim().Split('/');
            if (p.Length != 3) return false;
            date = Pc.ToDateTime(int.Parse(p[0]), int.Parse(p[1]), int.Parse(p[2]), 0, 0, 0, 0);
            return true;
        }
        catch { return false; }
    }

    public static DateTime MonthStart(DateTime date) => Pc.ToDateTime(Pc.GetYear(date), Pc.GetMonth(date), 1, 0, 0, 0, 0);
    public static DateTime YearStart(DateTime date) => Pc.ToDateTime(Pc.GetYear(date), 1, 1, 0, 0, 0, 0);
}
