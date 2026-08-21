namespace Tarazpad.Desktop.Infrastructure;

public static class NativeModuleOverrides
{
    public static ModuleDefinition? Get(string key)
    {
        var baseDefinition = ModuleCatalog.Get(key);
        if (baseDefinition is null) return null;

        return key switch
        {
            "parties" => baseDefinition with
            {
                CreateFields = new[]
                {
                    new FieldDefinition("name", "نام / عنوان شخص", Required:true),
                    new FieldDefinition("partyType", "نوع شخص", "select", DefaultValue:"LEGAL", Options:new[]{"LEGAL","NATURAL"}),
                    new FieldDefinition("role", "نقش طرف حساب", "select", DefaultValue:"CUSTOMER", Options:new[]{"CUSTOMER","SUPPLIER"}),
                    new FieldDefinition("code", "کد شخص"),
                    new FieldDefinition("nationalId", "کد/شناسه ملی"),
                    new FieldDefinition("economicCode", "کد اقتصادی"),
                    new FieldDefinition("mobile", "شماره موبایل")
                }
            },

            "treasury-receipts" => baseDefinition with
            {
                Endpoint = "api/iran/treasury/receipts?pageSize=200",
                SupportsSearch = true,
                CreateEndpoint = "api/iran/treasury/receipts",
                CreateFields = TreasuryFields(receipt:true)
            },

            "treasury-payments" => baseDefinition with
            {
                Endpoint = "api/iran/treasury/payments?pageSize=200",
                SupportsSearch = true,
                CreateEndpoint = "api/iran/treasury/payments",
                CreateFields = TreasuryFields(receipt:false)
            },

            _ => baseDefinition
        };
    }

    private static IReadOnlyList<FieldDefinition> TreasuryFields(bool receipt)
    {
        var dateKey = receipt ? "receiptDate" : "paymentDate";
        var dateLabel = receipt ? "تاریخ دریافت" : "تاریخ پرداخت";
        return new[]
        {
            new FieldDefinition("partyId", "طرف حساب", "lookup", LookupEndpoint:"api/iran/parties?pageSize=200", LookupDisplayKey:"name"),
            new FieldDefinition(dateKey, dateLabel, "jalali-date", Required:true, DefaultValue:"TODAY"),
            new FieldDefinition("method", "روش", "select", Required:true, DefaultValue:"BANK", Options: receipt
                ? new[]{"BANK","CASH","POS","TRANSFER","CHEQUE"}
                : new[]{"BANK","CASH","TRANSFER","CHEQUE","PETTY_CASH"}),
            new FieldDefinition("bankAccountId", "حساب بانکی (برای بانک/حواله)", "lookup", LookupEndpoint:"api/iran/treasury/bank-accounts", LookupDisplayKey:"account_title"),
            new FieldDefinition("amount", "مبلغ", "number", Required:true),
            new FieldDefinition("referenceNo", "شماره پیگیری / مرجع"),
            new FieldDefinition("chequeNo", "شماره چک (در روش چک)"),
            new FieldDefinition("bankName", "بانک صادرکننده چک"),
            new FieldDefinition("dueDate", "سررسید چک", "jalali-date"),
            new FieldDefinition("notes", "شرح / توضیحات", "multiline")
        };
    }
}
