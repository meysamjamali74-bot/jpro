using System.Globalization;
using System.Text.Json;

namespace Tarazpad.Desktop.Infrastructure;

public static class UiText
{
    private static readonly IReadOnlyDictionary<string, string> Values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
    {
        ["DRAFT"] = "پیش‌نویس", ["PREPARED"] = "آماده بررسی", ["CHECKED"] = "کنترل‌شده",
        ["APPROVED"] = "تأییدشده", ["POSTED"] = "ثبت قطعی", ["LOCKED"] = "قفل‌شده",
        ["VOID"] = "ابطال‌شده", ["OPEN"] = "باز", ["CLOSED"] = "بسته", ["ACTIVE"] = "فعال",
        ["INACTIVE"] = "غیرفعال", ["PAID"] = "تسویه‌شده", ["OUTSTANDING"] = "مانده‌دار",
        ["OVERDUE"] = "سررسیدگذشته", ["RECEIVED"] = "دریافت‌شده", ["ISSUED"] = "صادرشده",
        ["COLLECTED"] = "وصول‌شده", ["CLEARED"] = "پاس‌شده", ["RETURNED"] = "برگشتی",
        ["CANCELLED"] = "لغوشده", ["PENDING"] = "در انتظار", ["WAITING_APPROVAL"] = "در انتظار تأیید",
        ["SENT"] = "ارسال‌شده", ["CONFIRMED"] = "تأییدشده", ["DELIVERED"] = "تحویل‌شده",
        ["PARTIAL_DELIVERED"] = "تحویل جزئی", ["PARTIAL_DELIVERY"] = "تحویل جزئی", ["RESERVED"] = "رزروشده", ["PARTIAL_RESERVED"] = "رزرو جزئی",
        ["PICKING"] = "در حال برداشت", ["PICKED"] = "برداشت‌شده", ["PACKING"] = "در حال بسته‌بندی", ["PACKED"] = "بسته‌بندی‌شده",
        ["READY_TO_SHIP"] = "آماده ارسال", ["DISPATCHED"] = "ارسال‌شده", ["IN_TRANSIT"] = "در مسیر", ["NOT_REQUIRED"] = "نیاز ندارد",
        ["READY"] = "آماده", ["REJECTED"] = "ردشده", ["MATCH_PENDING"] = "در انتظار تطبیق",
        ["MATCH_EXCEPTION"] = "مغایرت تطبیق", ["RECEIVABLE"] = "دریافتی", ["PAYABLE"] = "پرداختی",
        ["BANK"] = "بانک", ["CASH"] = "نقد", ["POS"] = "کارتخوان", ["TRANSFER"] = "حواله بانکی",
        ["CHEQUE"] = "چک", ["PETTY_CASH"] = "تنخواه", ["LEGAL"] = "حقوقی", ["NATURAL"] = "حقیقی",
        ["GOODS"] = "کالا", ["SERVICE"] = "خدمت", ["EXPENSE"] = "هزینه", ["OFFICIAL"] = "رسمی", ["NON_OFFICIAL"] = "غیررسمی",
        ["STANDARD"] = "مشمول عادی", ["EXEMPT"] = "معاف", ["ZERO"] = "نرخ صفر", ["SPECIAL"] = "نرخ ویژه",
        ["LOW"] = "کم", ["NORMAL"] = "عادی", ["HIGH"] = "بالا", ["CRITICAL"] = "بحرانی",
        ["NEW"] = "جدید", ["PAUSED"] = "متوقف", ["WON"] = "موفق", ["LOST"] = "از دست‌رفته",
        ["DO_NOT_CONTACT"] = "عدم تماس", ["SOFT"] = "بستن نرم", ["HARD"] = "بستن قطعی",
        ["SOFT_CLOSED"] = "نرم بسته‌شده", ["HARD_CLOSED"] = "قطعی بسته‌شده",
        ["ASSET"] = "دارایی", ["LIABILITY"] = "بدهی", ["EQUITY"] = "حقوق مالکانه",
        ["REVENUE"] = "درآمد", ["DEBIT"] = "بدهکار", ["CREDIT"] = "بستانکار",
        ["MIXED"] = "مختلط", ["SUSPENDED"] = "تعلیق", ["TERMINATED"] = "خاتمه همکاری"
    };

    public static string Display(string? value)
    {
        var text = value?.Trim() ?? string.Empty;
        return Values.TryGetValue(text, out var localized) ? localized : text;
    }

    public static string Display(string key, JsonElement value)
    {
        if (value.ValueKind == JsonValueKind.Null) return string.Empty;
        if (value.ValueKind == JsonValueKind.True) return "بله";
        if (value.ValueKind == JsonValueKind.False) return "خیر";

        var raw = value.ValueKind == JsonValueKind.String ? value.GetString() ?? string.Empty : value.GetRawText();
        if (value.ValueKind == JsonValueKind.String && LooksLikeDateField(key) && DateTime.TryParse(raw, CultureInfo.InvariantCulture, DateTimeStyles.AssumeLocal, out var date))
        {
            var jalali = PersianDate.FromGregorian(date);
            return key.EndsWith("_at", StringComparison.OrdinalIgnoreCase) || key.EndsWith("At", StringComparison.Ordinal)
                ? $"{jalali} {date:HH:mm}"
                : jalali;
        }

        if (key.Contains("settlement", StringComparison.OrdinalIgnoreCase))
            return raw.ToUpperInvariant() switch { "CASH" => "نقدی", "CREDIT" => "اعتباری", "MIXED" => "ترکیبی", _ => Display(raw) };
        if (key.Contains("invoice_classification", StringComparison.OrdinalIgnoreCase))
            return raw.ToUpperInvariant() switch { "OFFICIAL" => "رسمی", "NON_OFFICIAL" => "غیررسمی", _ => Display(raw) };
        if (key.Contains("purchase_kind", StringComparison.OrdinalIgnoreCase))
            return raw.ToUpperInvariant() switch { "GOODS" => "کالا", "SERVICE" => "خدمت", "EXPENSE" => "هزینه", "ASSET" => "دارایی ثابت", _ => Display(raw) };
        if (key.Contains("fulfillment", StringComparison.OrdinalIgnoreCase)) return Display(raw);
        return Display(raw);
    }

    private static bool LooksLikeDateField(string key)
        => key.EndsWith("_date", StringComparison.OrdinalIgnoreCase)
           || key.EndsWith("_at", StringComparison.OrdinalIgnoreCase)
           || key.EndsWith("Date", StringComparison.Ordinal)
           || key.EndsWith("At", StringComparison.Ordinal)
           || key.Contains("due_", StringComparison.OrdinalIgnoreCase)
           || key.Contains("period_start", StringComparison.OrdinalIgnoreCase)
           || key.Contains("period_end", StringComparison.OrdinalIgnoreCase);
}
