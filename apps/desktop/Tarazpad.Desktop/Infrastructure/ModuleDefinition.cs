namespace Tarazpad.Desktop.Infrastructure;

public sealed record FieldDefinition(
    string Key,
    string Label,
    string Type = "text",
    bool Required = false,
    string? DefaultValue = null,
    IReadOnlyList<string>? Options = null,
    string? LookupEndpoint = null,
    string LookupValueKey = "id",
    string LookupDisplayKey = "name");

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
        ["id"] = "شناسه", ["code"] = "کد", ["name"] = "نام", ["title"] = "عنوان",
        ["status"] = "وضعیت", ["mobile"] = "موبایل", ["national_id"] = "شناسه ملی",
        ["economic_code"] = "کد اقتصادی", ["party_type"] = "نوع شخص", ["sku"] = "کد کالا",
        ["barcode"] = "بارکد", ["unit"] = "واحد", ["sale_price"] = "قیمت فروش",
        ["purchase_price"] = "قیمت خرید", ["on_hand_qty"] = "موجودی", ["reserved_qty"] = "رزرو",
        ["quarantine_qty"] = "قرنطینه", ["damaged_qty"] = "آسیب‌دیده", ["invoice_no"] = "شماره فاکتور",
        ["invoice_date"] = "تاریخ فاکتور", ["customer"] = "مشتری", ["supplier"] = "تأمین‌کننده",
        ["net_total"] = "مبلغ خالص", ["gross_total"] = "مبلغ ناخالص", ["tax_total"] = "مالیات",
        ["discount_total"] = "تخفیف", ["outstanding_amount"] = "مانده", ["priority"] = "اولویت",
        ["due_at"] = "سررسید", ["assigned_to"] = "مسئول", ["plate_no"] = "پلاک",
        ["route_name"] = "مسیر", ["driver_name"] = "راننده", ["debit"] = "بدهکار",
        ["credit"] = "بستانکار", ["balance"] = "مانده", ["credit_limit"] = "سقف اعتبار",
        ["payment_terms_days"] = "مهلت پرداخت", ["lifecycle_status"] = "مرحله مشتری", ["owner_name"] = "مسئول پیگیری",
        ["next_action_at"] = "اقدام بعدی", ["next_action_title"] = "عنوان اقدام بعدی", ["member_number"] = "شماره عضویت",
        ["points_balance"] = "امتیاز", ["receipt_no"] = "شماره دریافت", ["receipt_date"] = "تاریخ دریافت",
        ["payment_no"] = "شماره پرداخت", ["payment_date"] = "تاریخ پرداخت", ["party_name"] = "طرف حساب",
        ["method"] = "روش", ["amount"] = "مبلغ", ["reference_no"] = "شماره پیگیری",
        ["allocated_amount"] = "تخصیص‌یافته", ["bank_name"] = "بانک", ["account_title"] = "عنوان حساب",
        ["account_no"] = "شماره حساب", ["iban"] = "شبا", ["card_no"] = "کارت", ["opening_balance"] = "مانده افتتاحیه",
        ["cheque_no"] = "شماره چک", ["cheque_type"] = "نوع چک", ["due_date"] = "سررسید", ["days_to_due"] = "روز تا سررسید",
        ["supplier_invoice_no"] = "شماره فاکتور تأمین‌کننده", ["received_value"] = "ارزش دریافت", ["po_no"] = "شماره سفارش خرید",
        ["year_no"] = "سال", ["month_no"] = "ماه", ["employee_count"] = "تعداد کارکنان", ["total_gross"] = "ناخالص حقوق",
        ["total_deduction"] = "کسورات", ["total_net"] = "خالص پرداختنی", ["entry_no"] = "شماره سند",
        ["entry_date"] = "تاریخ سند", ["gl_account_code"] = "کد حساب معین", ["gl_account_title"] = "حساب معین",
        ["asset_no"] = "کد دارایی", ["class_title"] = "طبقه دارایی", ["custodian"] = "تحویل‌گیرنده",
        ["acquisition_date"] = "تاریخ تحصیل", ["acquisition_cost"] = "بهای تمام‌شده", ["book_value"] = "ارزش دفتری",
        ["period_start"] = "شروع دوره", ["period_end"] = "پایان دوره", ["total_depreciation"] = "استهلاک دوره",
        ["personnel_no"] = "شماره پرسنلی", ["department_title"] = "واحد", ["position_title"] = "سمت",
        ["employment_status"] = "وضعیت استخدام", ["contract_no"] = "شماره قرارداد", ["start_date"] = "شروع",
        ["end_date"] = "پایان", ["rate"] = "نرخ", ["tax_kind"] = "نوع مالیات", ["tax_code"] = "کد مالیات",
        ["effective_from"] = "از تاریخ", ["effective_to"] = "تا تاریخ", ["period_title"] = "دوره مالی",
        ["close_mode"] = "نوع بستن", ["blocker_count"] = "موارد مسدودکننده", ["warning_count"] = "هشدارها",
        ["total_budget"] = "بودجه", ["line_count"] = "تعداد ردیف", ["revenue"] = "درآمد", ["cost"] = "هزینه", ["profit"] = "سود"
    };

    private static FieldDefinition PartyLookup(string key = "partyId", string label = "طرف حساب", bool required = false)
        => new(key, label, "lookup", required, LookupEndpoint:"api/parties", LookupDisplayKey:"name");

    public static ModuleDefinition? Get(string key)
    {
        var c = CommonColumns;
        return key switch
        {
            "tasks" => new(key, "کارتابل و وظایف", "ثبت، اولویت‌بندی و پیگیری کارهای روزانه", "api/tasks", false,
                "api/tasks", new[] {
                    new FieldDefinition("title", "عنوان وظیفه", Required:true),
                    new FieldDefinition("description", "شرح", "multiline"),
                    new FieldDefinition("priority", "اولویت", "select", DefaultValue:"NORMAL", Options:new[]{"LOW","NORMAL","HIGH","CRITICAL"}),
                    new FieldDefinition("dueAt", "موعد انجام", "jalali-date") }, c),

            "accounts" => new(key, "کدینگ حساب‌ها", "ساختار حساب‌ها، ماهیت و امکان ثبت مستقیم", "api/iran/accounts", true,
                "api/iran/accounts", new[] {
                    new FieldDefinition("code", "کد حساب", Required:true),
                    new FieldDefinition("title", "عنوان حساب", Required:true),
                    new FieldDefinition("accountType", "نوع حساب", "select", Required:true, Options:new[]{"ASSET","LIABILITY","EQUITY","REVENUE","EXPENSE"}),
                    new FieldDefinition("nature", "ماهیت", "select", DefaultValue:"MIXED", Options:new[]{"DEBIT","CREDIT","MIXED"}) }, c),
            "accounting" => new(key, "تراز آزمایشی", "کنترل بدهکار، بستانکار و مانده حساب‌ها", "api/finance/trial-balance", false, null, null, c),
            "fiscal-years" => new(key, "سال‌های مالی", "سال مالی و دوره‌های شمسی", "api/iran/finance/fiscal-years", false,
                "api/iran/finance/fiscal-years", new[] {
                    new FieldDefinition("yearNo", "سال شمسی", "number", Required:true, DefaultValue:"1405"),
                    new FieldDefinition("title", "عنوان سال مالی") }, c),
            "close-runs" => new(key, "بستن دوره", "کنترل‌های پایان دوره و وضعیت بستن حساب‌ها", "api/iran/finance/close-runs", false, null, null, c),

            "parties" => new(key, "اشخاص", "مشتریان، تأمین‌کنندگان و سایر طرف‌حساب‌ها", "api/iran/parties?pageSize=200", true,
                "api/iran/parties", new[] {
                    new FieldDefinition("name", "نام / عنوان شخص", Required:true),
                    new FieldDefinition("partyType", "نوع شخص", "select", DefaultValue:"LEGAL", Options:new[]{"LEGAL","NATURAL"}),
                    new FieldDefinition("code", "کد شخص"), new FieldDefinition("nationalId", "کد/شناسه ملی"),
                    new FieldDefinition("economicCode", "کد اقتصادی"), new FieldDefinition("mobile", "شماره موبایل") }, c),

            "inventory" => new(key, "کالا و انبار", "کالاها، موجودی، رزرو و قیمت‌های پایه", "api/iran/products", true,
                "api/iran/products", new[] {
                    new FieldDefinition("sku", "کد کالا", Required:true), new FieldDefinition("name", "نام کالا", Required:true),
                    new FieldDefinition("unit", "واحد", DefaultValue:"عدد"), new FieldDefinition("barcode", "بارکد"),
                    new FieldDefinition("purchasePrice", "قیمت خرید", "number", DefaultValue:"0"),
                    new FieldDefinition("salePrice", "قیمت فروش", "number", DefaultValue:"0"),
                    new FieldDefinition("productType", "نوع", "select", DefaultValue:"GOODS", Options:new[]{"GOODS","SERVICE"}) }, c),

            "sales" => new(key, "فاکتورهای فروش", "فاکتور، مالیات، مانده مشتری و وضعیت وصول", "api/iran/sales-invoices?pageSize=200", true, null, null, c),
            "purchase-invoices" => new(key, "فاکتورهای خرید", "کنترل خرید، تطبیق با سفارش و رسید انبار", "api/iran/purchase-invoices", true, null, null, c),
            "goods-receipts" => new(key, "رسیدهای انبار خرید", "رسید کالا، ارزش دریافت و وضعیت ثبت حسابداری", "api/iran/goods-receipts", true, null, null, c),
            "logistics" => new(key, "لجستیک و توزیع", "سفرها، رانندگان، مسیرها و وضعیت تحویل", "api/logistics/trips", false, null, null, c),

            "crm" => new(key, "باشگاه مشتریان", "مالک مشتری، مرحله ارتباط و اقدام بعدی", "api/iran/customer-club/customers", true,
                "api/iran/customer-club/customers", new[] {
                    new FieldDefinition("name", "نام مشتری", Required:true), new FieldDefinition("mobile", "موبایل"),
                    new FieldDefinition("nationalId", "کد/شناسه ملی"),
                    new FieldDefinition("priority", "اولویت", "select", DefaultValue:"NORMAL", Options:new[]{"LOW","NORMAL","HIGH","CRITICAL"}),
                    new FieldDefinition("source", "منبع جذب", DefaultValue:"DESKTOP"), new FieldDefinition("nextActionTitle", "اقدام بعدی"),
                    new FieldDefinition("nextActionAt", "تاریخ اقدام بعدی", "jalali-date") }, c),

            "treasury-receipts" => new(key, "دریافت‌ها", "دریافت نقد، بانک، کارت و اسناد وصولی", "api/treasury/receipts", false,
                "api/treasury/receipts", new[] {
                    PartyLookup(), new FieldDefinition("receiptDate", "تاریخ دریافت", "jalali-date", DefaultValue:"TODAY"),
                    new FieldDefinition("method", "روش دریافت", "select", Required:true, DefaultValue:"BANK", Options:new[]{"BANK","CASH","POS","TRANSFER"}),
                    new FieldDefinition("amount", "مبلغ", "number", Required:true), new FieldDefinition("referenceNo", "شماره پیگیری") }, c),

            "treasury-payments" => new(key, "پرداخت‌ها", "پرداخت به تأمین‌کننده و سایر ذی‌نفعان", "api/treasury/payments", false,
                "api/treasury/payments", new[] {
                    PartyLookup(), new FieldDefinition("paymentDate", "تاریخ پرداخت", "jalali-date", DefaultValue:"TODAY"),
                    new FieldDefinition("method", "روش پرداخت", "select", Required:true, DefaultValue:"BANK", Options:new[]{"BANK","CASH","TRANSFER"}),
                    new FieldDefinition("amount", "مبلغ", "number", Required:true), new FieldDefinition("referenceNo", "شماره پیگیری") }, c),

            "bank-accounts" => new(key, "حساب‌های بانکی", "تعریف حساب، شبا، کارت و مانده افتتاحیه", "api/iran/treasury/bank-accounts", true,
                "api/iran/treasury/bank-accounts", new[] {
                    new FieldDefinition("code", "کد حساب بانکی", Required:true), new FieldDefinition("bankName", "نام بانک", Required:true),
                    new FieldDefinition("accountTitle", "عنوان حساب", Required:true), new FieldDefinition("accountNo", "شماره حساب"),
                    new FieldDefinition("iban", "شماره شبا"), new FieldDefinition("cardNo", "شماره کارت"),
                    new FieldDefinition("openingBalance", "مانده افتتاحیه", "number", DefaultValue:"0") }, c),

            "cheques" => new(key, "چک‌ها", "چک‌های دریافتی و پرداختی و کنترل سررسید", "api/treasury/cheques", false,
                "api/treasury/cheques", new[] {
                    new FieldDefinition("chequeType", "نوع چک", "select", Required:true, DefaultValue:"RECEIVABLE", Options:new[]{"RECEIVABLE","PAYABLE"}),
                    new FieldDefinition("chequeNo", "شماره چک", Required:true), PartyLookup(), new FieldDefinition("bankName", "نام بانک"),
                    new FieldDefinition("amount", "مبلغ", "number", Required:true), new FieldDefinition("dueDate", "تاریخ سررسید", "jalali-date", Required:true),
                    new FieldDefinition("referenceNo", "شماره پیگیری") }, c),

            "asset-classes" => new(key, "طبقات دارایی ثابت", "طبقه‌بندی و حساب‌های مرتبط با استهلاک", "api/iran/finance/asset-classes", false, null, null, c),
            "assets" => new(key, "دارایی‌های ثابت", "اموال، بهای تمام‌شده، تحویل‌گیرنده و وضعیت دارایی", "api/iran/finance/assets", false, null, null, c),
            "depreciation-runs" => new(key, "محاسبات استهلاک", "کنترل دوره‌های محاسبه و ثبت استهلاک", "api/iran/finance/depreciation-runs", false, null, null, c),
            "budgets" => new(key, "بودجه", "نسخه‌های بودجه و کنترل مبالغ مصوب", "api/iran/finance/budgets", false, null, null, c),
            "projects" => new(key, "پروژه‌ها", "درآمد، هزینه و سود پروژه‌ها", "api/iran/finance/projects", false, null, null, c),

            "employees" => new(key, "کارکنان", "پرونده پرسنلی، واحد، سمت و وضعیت استخدام", "api/iran/hr/employees?pageSize=200", true,
                "api/iran/hr/employees", new[] {
                    new FieldDefinition("name", "نام و نام خانوادگی", Required:true), new FieldDefinition("personnelNo", "شماره پرسنلی", Required:true),
                    new FieldDefinition("nationalNo", "کد ملی"), new FieldDefinition("mobile", "موبایل"),
                    new FieldDefinition("hireDate", "تاریخ استخدام", "jalali-date"),
                    new FieldDefinition("employmentStatus", "وضعیت", "select", DefaultValue:"ACTIVE", Options:new[]{"ACTIVE","SUSPENDED","TERMINATED"}) }, c),
            "positions" => new(key, "سمت‌ها", "سمت‌ها و رده‌های سازمانی", "api/iran/hr/positions", false,
                "api/iran/hr/positions", new[] { new FieldDefinition("code", "کد سمت", Required:true), new FieldDefinition("title", "عنوان سمت", Required:true), new FieldDefinition("grade", "گرید") }, c),
            "contracts" => new(key, "قراردادهای کارکنان", "قرارداد، دستمزد و مزایای ثابت", "api/iran/hr/contracts", true, null, null, c),
            "payroll-batches" => new(key, "دوره‌های حقوق", "حقوق و دستمزد بر مبنای سال و ماه شمسی", "api/iran/payroll/batches", false,
                "api/iran/payroll/batches", new[] {
                    new FieldDefinition("yearNo", "سال شمسی", "number", Required:true, DefaultValue:"1405"), new FieldDefinition("monthNo", "ماه", "number", Required:true),
                    new FieldDefinition("title", "عنوان دوره") }, c),
            "payroll-legal" => new(key, "پارامترهای قانونی حقوق", "معافیت، بیمه و ضرایب قانونی دوره‌های حقوق", "api/iran/payroll/legal-parameters", false, null, null, c),

            "tax-rates" => new(key, "نرخ‌های مالیاتی", "نرخ‌های مالیات و ارزش افزوده مؤثر در دوره‌ها", "api/iran/tax/rates", false, null, null, c),
            "ar-credit-notes" => new(key, "اعتبارنامه مشتریان", "اصلاحات حساب دریافتنی و برگشت/تعدیل فروش", "api/iran/finance/ar-credit-notes", false, null, null, c),
            "ap-debit-notes" => new(key, "بدهکارنامه تأمین‌کنندگان", "اصلاحات حساب پرداختنی و تعدیلات خرید", "api/iran/finance/ap-debit-notes", false, null, null, c),

            _ => null
        };
    }
}
