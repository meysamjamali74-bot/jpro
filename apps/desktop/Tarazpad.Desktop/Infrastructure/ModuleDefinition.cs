namespace Tarazpad.Desktop.Infrastructure;

public sealed record FieldDefinition(
    string Key,
    string Label,
    string Type = "text",
    bool Required = false,
    string? DefaultValue = null,
    IReadOnlyList<string>? Options = null);

public sealed record ModuleDefinition(
    string Key,
    string Title,
    string Subtitle,
    string Endpoint,
    bool SupportsSearch = false,
    string? CreateEndpoint = null,
    IReadOnlyList<FieldDefinition>? CreateFields = null,
    IReadOnlyDictionary<string, string>? ColumnTitles = null,
    string EmptyMessage = "داده‌ای برای نمایش وجود ندارد.");

public static class ModuleCatalog
{
    private static readonly IReadOnlyDictionary<string, string> CommonColumns = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
    {
        ["id"] = "شناسه",
        ["code"] = "کد",
        ["name"] = "نام",
        ["title"] = "عنوان",
        ["status"] = "وضعیت",
        ["mobile"] = "موبایل",
        ["national_id"] = "شناسه ملی",
        ["party_type"] = "نوع شخص",
        ["sku"] = "کد کالا",
        ["barcode"] = "بارکد",
        ["unit"] = "واحد",
        ["sale_price"] = "قیمت فروش",
        ["on_hand_qty"] = "موجودی",
        ["reserved_qty"] = "رزرو",
        ["invoice_no"] = "شماره فاکتور",
        ["invoice_date"] = "تاریخ فاکتور",
        ["customer"] = "مشتری",
        ["net_total"] = "مبلغ خالص",
        ["outstanding_amount"] = "مانده",
        ["priority"] = "اولویت",
        ["due_at"] = "سررسید",
        ["assigned_to"] = "مسئول",
        ["plate_no"] = "پلاک",
        ["route_name"] = "مسیر",
        ["driver_name"] = "راننده",
        ["debit"] = "بدهکار",
        ["credit"] = "بستانکار",
        ["balance"] = "مانده",
        ["credit_limit"] = "سقف اعتبار",
        ["payment_terms_days"] = "مهلت پرداخت",
        ["lifecycle_status"] = "مرحله مشتری",
        ["owner_name"] = "مسئول پیگیری",
        ["next_action_at"] = "اقدام بعدی",
        ["next_action_title"] = "عنوان اقدام بعدی",
        ["member_number"] = "شماره عضویت",
        ["points_balance"] = "امتیاز",
    };

    public static ModuleDefinition? Get(string key)
    {
        var columns = CommonColumns;
        return key switch
        {
            "tasks" => new(key, "کارتابل و وظایف", "ثبت، اولویت‌بندی و پیگیری کارهای روزانه", "api/tasks", false,
                "api/tasks",
                new[]
                {
                    new FieldDefinition("title", "عنوان وظیفه", Required:true),
                    new FieldDefinition("description", "شرح", "multiline"),
                    new FieldDefinition("priority", "اولویت", "select", DefaultValue:"NORMAL", Options:new[]{"LOW","NORMAL","HIGH","CRITICAL"}),
                    new FieldDefinition("dueAt", "موعد انجام", "datetime")
                }, columns),
            "accounting" => new(key, "حسابداری و اسناد", "تراز آزمایشی و کنترل مانده حساب‌ها", "api/finance/trial-balance", false, null, null, columns),
            "parties" => new(key, "اشخاص", "مشتریان، تأمین‌کنندگان و سایر طرف‌حساب‌ها", "api/parties", true,
                "api/parties",
                new[]
                {
                    new FieldDefinition("name", "نام / عنوان شخص", Required:true),
                    new FieldDefinition("partyType", "نوع شخص", "select", DefaultValue:"LEGAL", Options:new[]{"LEGAL","NATURAL"}),
                    new FieldDefinition("nationalId", "کد/شناسه ملی"),
                    new FieldDefinition("mobile", "شماره موبایل")
                }, columns),
            "inventory" => new(key, "کالا و انبار", "کالاها، موجودی، رزرو و قیمت فروش", "api/products", true,
                "api/products",
                new[]
                {
                    new FieldDefinition("sku", "کد کالا", Required:true),
                    new FieldDefinition("name", "نام کالا", Required:true),
                    new FieldDefinition("unit", "واحد", DefaultValue:"عدد"),
                    new FieldDefinition("barcode", "بارکد"),
                    new FieldDefinition("salePrice", "قیمت فروش", "number", DefaultValue:"0")
                }, columns),
            "sales" => new(key, "فروش", "فاکتورهای فروش، مانده مشتری و وضعیت وصول", "api/sales/invoices", false, null, null, columns),
            "purchases" => new(key, "خرید و تأمین", "وضعیت اسناد خرید و کنترل تأمین", "api/status/purchases", false, null, null, columns),
            "logistics" => new(key, "لجستیک و توزیع", "سفرها، رانندگان، مسیرها و وضعیت تحویل", "api/logistics/trips", false, null, null, columns),
            "crm" => new(key, "باشگاه مشتریان", "مالک مشتری، مرحله ارتباط و اقدام بعدی", "api/iran/customer-club/customers", true,
                "api/iran/customer-club/customers",
                new[]
                {
                    new FieldDefinition("name", "نام مشتری", Required:true),
                    new FieldDefinition("mobile", "موبایل"),
                    new FieldDefinition("nationalId", "کد/شناسه ملی"),
                    new FieldDefinition("priority", "اولویت", "select", DefaultValue:"NORMAL", Options:new[]{"LOW","NORMAL","HIGH","CRITICAL"}),
                    new FieldDefinition("source", "منبع جذب", DefaultValue:"DESKTOP"),
                    new FieldDefinition("nextActionTitle", "اقدام بعدی"),
                    new FieldDefinition("nextActionAt", "زمان اقدام بعدی", "datetime")
                }, columns),
            _ => null
        };
    }
}
