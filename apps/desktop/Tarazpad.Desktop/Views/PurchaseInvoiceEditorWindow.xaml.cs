using System.Collections.ObjectModel;
using System.Globalization;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using Tarazpad.Desktop.Infrastructure;

namespace Tarazpad.Desktop.Views;

public partial class PurchaseInvoiceEditorWindow : Window
{
    private sealed record ContextLine(long Id, long ProductId, decimal UnitPrice, decimal RemainingQty, string GoodsServiceId, string UnitCode, string VatStatus, decimal VatRate);

    private readonly ObservableCollection<InvoiceLineDraft> _lines = new();
    private IReadOnlyList<PartyLookupItem> _suppliers = Array.Empty<PartyLookupItem>();
    private IReadOnlyList<ProductLookupItem> _products = Array.Empty<ProductLookupItem>();
    private IReadOnlyList<ProcurementLookupItem> _orders = Array.Empty<ProcurementLookupItem>();
    private IReadOnlyList<ProcurementLookupItem> _receipts = Array.Empty<ProcurementLookupItem>();
    private readonly Dictionary<long, ContextLine> _poLines = new();
    private readonly Dictionary<long, ContextLine> _grLines = new();
    private decimal _defaultVatRate;
    private bool _syncing;

    public PurchaseInvoiceEditorWindow()
    {
        InitializeComponent();
        InvoiceDateBox.Text = PersianDate.Today();
        LinesGrid.ItemsSource = _lines;
        Loaded += async (_, _) => await LoadLookupsAsync();
    }

    private async Task LoadLookupsAsync()
    {
        try
        {
            ErrorText.Text = "در حال دریافت اطلاعات پایه خرید...";
            var root = await App.Api.GetJsonAsync("api/native/document-lookups");
            _suppliers = DocumentJson.Parties(root, "suppliers");
            _products = DocumentJson.Products(root);
            _orders = DocumentJson.PurchaseOrders(root);
            _receipts = DocumentJson.GoodsReceipts(root);
            SupplierBox.ItemsSource = _suppliers;
            ProductBox.ItemsSource = _products;
            PurchaseOrderBox.ItemsSource = _orders;
            GoodsReceiptBox.ItemsSource = _receipts;
            if (root.TryGetProperty("vatRates", out var rates) && rates.ValueKind == JsonValueKind.Array)
            {
                var first = rates.EnumerateArray().FirstOrDefault();
                if (first.ValueKind == JsonValueKind.Object) _defaultVatRate = DocumentJson.Decimal(first, "rate");
            }
            VatRateBox.Text = _defaultVatRate.ToString("0.##", CultureInfo.InvariantCulture);
            ErrorText.Text = string.Empty;
        }
        catch (Exception ex)
        {
            ErrorText.Text = ex.Message;
            SaveButton.IsEnabled = false;
        }
    }

    private async void SupplierBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_syncing || SupplierBox.SelectedItem is not PartyLookupItem supplier) return;
        _syncing = true;
        PurchaseOrderBox.ItemsSource = _orders.Where(x => x.SupplierPartyId == supplier.Id).ToList();
        GoodsReceiptBox.ItemsSource = _receipts.Where(x => x.SupplierPartyId == supplier.Id).ToList();
        if (PurchaseOrderBox.SelectedItem is ProcurementLookupItem po && po.SupplierPartyId != supplier.Id) PurchaseOrderBox.SelectedItem = null;
        if (GoodsReceiptBox.SelectedItem is ProcurementLookupItem gr && gr.SupplierPartyId != supplier.Id) GoodsReceiptBox.SelectedItem = null;
        _syncing = false;
        await LoadProcurementContextAsync();
        if (supplier.PaymentTermsDays > 0 && PersianDate.TryToGregorian(InvoiceDateBox.Text, out var invoiceDate))
            DueDateBox.Text = PersianDate.FromGregorian(invoiceDate.AddDays(supplier.PaymentTermsDays));
    }

    private async void PurchaseOrderBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_syncing) return;
        if (PurchaseOrderBox.SelectedItem is ProcurementLookupItem po)
        {
            _syncing = true;
            SupplierBox.SelectedItem = _suppliers.FirstOrDefault(x => x.Id == po.SupplierPartyId);
            GoodsReceiptBox.ItemsSource = _receipts.Where(x => x.PurchaseOrderId == po.Id || (x.PurchaseOrderId is null && x.SupplierPartyId == po.SupplierPartyId)).ToList();
            if (GoodsReceiptBox.SelectedItem is ProcurementLookupItem gr && gr.PurchaseOrderId != po.Id) GoodsReceiptBox.SelectedItem = null;
            _syncing = false;
        }
        await LoadProcurementContextAsync();
    }

    private async void GoodsReceiptBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_syncing) return;
        if (GoodsReceiptBox.SelectedItem is ProcurementLookupItem gr)
        {
            _syncing = true;
            SupplierBox.SelectedItem = _suppliers.FirstOrDefault(x => x.Id == gr.SupplierPartyId);
            if (gr.PurchaseOrderId is long poId && poId > 0)
            {
                PurchaseOrderBox.ItemsSource = _orders.Where(x => x.SupplierPartyId == gr.SupplierPartyId).ToList();
                PurchaseOrderBox.SelectedItem = _orders.FirstOrDefault(x => x.Id == poId);
            }
            _syncing = false;
        }
        await LoadProcurementContextAsync();
    }

    private async Task LoadProcurementContextAsync()
    {
        _poLines.Clear();
        _grLines.Clear();
        var poId = (PurchaseOrderBox.SelectedItem as ProcurementLookupItem)?.Id ?? 0;
        var grId = (GoodsReceiptBox.SelectedItem as ProcurementLookupItem)?.Id ?? 0;
        if (poId <= 0 && grId <= 0)
        {
            ContextText.Text = "بدون اتصال سفارش/رسید؛ خرید کالایی در تطبیق به‌عنوان مغایرت گزارش می‌شود.";
            return;
        }
        try
        {
            var parts = new List<string>();
            if (poId > 0) parts.Add($"purchaseOrderId={poId}");
            if (grId > 0) parts.Add($"goodsReceiptId={grId}");
            var root = await App.Api.GetJsonAsync("api/iran/procurement/context?" + string.Join("&", parts));
            if (root.TryGetProperty("poLines", out var poLines) && poLines.ValueKind == JsonValueKind.Array)
            {
                foreach (var x in poLines.EnumerateArray())
                {
                    var productId = DocumentJson.Long(x, "product_id");
                    var remaining = Math.Max(0, DocumentJson.Decimal(x, "received_qty") - DocumentJson.Decimal(x, "invoiced_qty"));
                    _poLines[productId] = new ContextLine(DocumentJson.Long(x, "id"), productId, DocumentJson.Decimal(x, "unit_price"), remaining,
                        DocumentJson.String(x, "goods_service_id"), DocumentJson.String(x, "unit_code"), DocumentJson.String(x, "vat_status"), DocumentJson.Decimal(x, "default_vat_rate"));
                }
            }
            if (root.TryGetProperty("grLines", out var grLines) && grLines.ValueKind == JsonValueKind.Array)
            {
                foreach (var x in grLines.EnumerateArray())
                {
                    var productId = DocumentJson.Long(x, "product_id");
                    _grLines[productId] = new ContextLine(DocumentJson.Long(x, "id"), productId, DocumentJson.Decimal(x, "unit_cost"), DocumentJson.Decimal(x, "accepted_qty"),
                        DocumentJson.String(x, "goods_service_id"), DocumentJson.String(x, "unit_code"), DocumentJson.String(x, "vat_status"), DocumentJson.Decimal(x, "default_vat_rate"));
                }
            }
            ContextText.Text = $"اتصال فعال: {(poId > 0 ? "سفارش خرید" : string.Empty)}{(poId > 0 && grId > 0 ? " + " : string.Empty)}{(grId > 0 ? "رسید انبار" : string.Empty)} • ردیف‌ها هنگام ثبت به اسناد مبنا متصل می‌شوند.";
            if (ProductBox.SelectedItem is ProductLookupItem) ProductBox_SelectionChanged(ProductBox, new SelectionChangedEventArgs(Selector.SelectionChangedEvent, Array.Empty<object>(), Array.Empty<object>()));
        }
        catch (Exception ex) { ContextText.Text = ex.Message; }
    }

    private void ProductBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (ProductBox.SelectedItem is not ProductLookupItem product) return;
        _poLines.TryGetValue(product.Id, out var poLine);
        _grLines.TryGetValue(product.Id, out var grLine);
        var price = poLine?.UnitPrice > 0 ? poLine.UnitPrice : grLine?.UnitPrice > 0 ? grLine.UnitPrice : product.PurchasePrice;
        PriceBox.Text = price.ToString("0.##", CultureInfo.InvariantCulture);
        var remaining = poLine?.RemainingQty ?? grLine?.RemainingQty ?? 0;
        if (remaining > 0) QtyBox.Text = remaining.ToString("0.####", CultureInfo.InvariantCulture);
        LineDescriptionBox.Text = product.Name;
        var vatStatus = !string.IsNullOrWhiteSpace(poLine?.VatStatus) ? poLine.VatStatus : !string.IsNullOrWhiteSpace(product.VatStatus) ? product.VatStatus : "STANDARD";
        SelectTag(VatStatusBox, vatStatus);
        var vatRate = poLine?.VatRate > 0 ? poLine.VatRate : product.VatRate > 0 ? product.VatRate : _defaultVatRate;
        VatRateBox.Text = vatRate.ToString("0.##", CultureInfo.InvariantCulture);
        MatchHintText.Text = $"{(poLine is not null ? "✓ ردیف سفارش خرید" : "○ بدون ردیف سفارش")}   {(grLine is not null ? "✓ ردیف رسید انبار" : "○ بدون ردیف رسید")}";
    }

    private void ClassificationBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (!IsLoaded) return;
        var official = SelectedTag(ClassificationBox) == "OFFICIAL";
        TaxTypeBox.IsEnabled = official;
        TaxUniqueNoBox.IsEnabled = official;
        if (!official) TaxUniqueNoBox.Clear();
    }

    private void AddLine_Click(object sender, RoutedEventArgs e)
    {
        ErrorText.Text = string.Empty;
        if (ProductBox.SelectedItem is not ProductLookupItem product) { ErrorText.Text = "کالا یا خدمت را انتخاب کنید."; return; }
        if (!TryNumber(QtyBox.Text, out var qty) || qty <= 0) { ErrorText.Text = "مقدار ردیف باید بیشتر از صفر باشد."; return; }
        if (!TryNumber(PriceBox.Text, out var price) || price < 0) { ErrorText.Text = "قیمت واحد معتبر نیست."; return; }
        TryNumber(DiscountBox.Text, out var discount); TryNumber(VatRateBox.Text, out var vatRate); TryNumber(DutiesBox.Text, out var duties);
        var gross = qty * price;
        if (discount < 0 || discount > gross) { ErrorText.Text = "تخفیف ردیف نمی‌تواند بیشتر از مبلغ ناخالص باشد."; return; }
        if (vatRate < 0 || duties < 0) { ErrorText.Text = "مالیات و عوارض نمی‌تواند منفی باشد."; return; }
        _poLines.TryGetValue(product.Id, out var poLine); _grLines.TryGetValue(product.Id, out var grLine);
        var vatStatus = SelectedTag(VatStatusBox);
        _lines.Add(new InvoiceLineDraft
        {
            ProductId = product.Id, Sku = product.Sku, ProductName = product.Name, Unit = product.Unit, ProductType = product.ProductType,
            Qty = qty, UnitPrice = price, DiscountAmount = discount, VatStatus = vatStatus,
            VatRate = vatStatus is "EXEMPT" or "ZERO" ? 0 : vatRate, OtherDutiesAmount = duties,
            Description = string.IsNullOrWhiteSpace(LineDescriptionBox.Text) ? product.Name : LineDescriptionBox.Text.Trim(),
            GoodsServiceId = !string.IsNullOrWhiteSpace(poLine?.GoodsServiceId) ? poLine.GoodsServiceId : product.GoodsServiceId,
            UnitCode = !string.IsNullOrWhiteSpace(poLine?.UnitCode) ? poLine.UnitCode : product.UnitCode,
            PurchaseOrderLineId = poLine?.Id, GoodsReceiptLineId = grLine?.Id
        });
        ResetLineInputs(); UpdateTotals();
    }

    private void RemoveLine_Click(object sender, RoutedEventArgs e)
    {
        if (LinesGrid.SelectedItem is InvoiceLineDraft line) _lines.Remove(line);
        UpdateTotals();
    }

    private async void Save_Click(object sender, RoutedEventArgs e)
    {
        ErrorText.Text = string.Empty;
        if (SupplierBox.SelectedItem is not PartyLookupItem supplier) { ErrorText.Text = "انتخاب تأمین‌کننده الزامی است."; return; }
        if (string.IsNullOrWhiteSpace(SupplierInvoiceNoBox.Text)) { ErrorText.Text = "شماره فاکتور تأمین‌کننده را وارد کنید."; return; }
        if (_lines.Count == 0) { ErrorText.Text = "حداقل یک ردیف خرید ثبت کنید."; return; }
        if (!PersianDate.TryToGregorian(InvoiceDateBox.Text, out var invoiceDate)) { ErrorText.Text = "تاریخ فاکتور شمسی معتبر نیست."; return; }
        DateTime? dueDate = null;
        if (!string.IsNullOrWhiteSpace(DueDateBox.Text))
        {
            if (!PersianDate.TryToGregorian(DueDateBox.Text, out var parsedDue)) { ErrorText.Text = "تاریخ سررسید شمسی معتبر نیست."; return; }
            dueDate = parsedDue;
        }
        var classification = SelectedTag(ClassificationBox);
        if (classification == "OFFICIAL" && string.IsNullOrWhiteSpace(TaxUniqueNoBox.Text)) { ErrorText.Text = "برای فاکتور خرید رسمی، شماره منحصر‌به‌فرد مالیاتی الزامی است."; return; }
        var purchaseKind = SelectedTag(PurchaseKindBox);
        var po = PurchaseOrderBox.SelectedItem as ProcurementLookupItem;
        var gr = GoodsReceiptBox.SelectedItem as ProcurementLookupItem;
        if (purchaseKind == "GOODS" && (po is null || gr is null))
        {
            var answer = MessageBox.Show("این خرید کالایی به سفارش خرید و رسید انبار کامل متصل نیست؛ در تطبیق سه‌جانبه مغایرت ثبت خواهد شد. با این حال فاکتور ذخیره شود؟", "کنترل خرید", MessageBoxButton.YesNo, MessageBoxImage.Warning);
            if (answer != MessageBoxResult.Yes) return;
        }

        SaveButton.IsEnabled = false;
        try
        {
            var payload = new
            {
                supplierPartyId = supplier.Id,
                supplierInvoiceNo = SupplierInvoiceNoBox.Text.Trim(),
                invoiceDate = invoiceDate.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
                dueDate = dueDate?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
                invoiceClassification = classification,
                taxInvoiceType = classification == "OFFICIAL" ? SelectedTag(TaxTypeBox) : null,
                taxUniqueNo = classification == "OFFICIAL" ? TaxUniqueNoBox.Text.Trim() : null,
                settlementType = SelectedTag(SettlementBox),
                purchaseKind,
                purchaseOrderId = po?.Id,
                goodsReceiptId = gr?.Id,
                notes = string.IsNullOrWhiteSpace(NotesBox.Text) ? null : NotesBox.Text.Trim(),
                lines = _lines.Select(x => new
                {
                    productId = x.ProductId, description = x.Description, qty = x.Qty, unitPrice = x.UnitPrice,
                    discountAmount = x.DiscountAmount, vatStatus = x.VatStatus, vatRate = x.VatRate,
                    otherDutiesAmount = x.OtherDutiesAmount, goodsServiceId = x.GoodsServiceId, unitCode = x.UnitCode,
                    purchaseOrderLineId = x.PurchaseOrderLineId, goodsReceiptLineId = x.GoodsReceiptLineId
                }).ToArray()
            };
            var result = await App.Api.SendJsonAsync(HttpMethod.Post, "api/iran/purchase-invoices/auto", payload);
            var invoiceNo = DocumentJson.String(result, "invoiceNo");
            MessageBox.Show($"فاکتور خرید {invoiceNo} ثبت شد و آماده تطبیق سه‌جانبه است.", "ترازپاد", MessageBoxButton.OK, MessageBoxImage.Information);
            DialogResult = true; Close();
        }
        catch (Exception ex) { ErrorText.Text = ex.Message; SaveButton.IsEnabled = true; }
    }

    private void UpdateTotals()
    {
        GrossText.Text = _lines.Sum(x => x.Gross).ToString("N0"); DiscountText.Text = _lines.Sum(x => x.DiscountAmount).ToString("N0");
        TaxText.Text = _lines.Sum(x => x.Tax).ToString("N0"); DutiesText.Text = _lines.Sum(x => x.OtherDutiesAmount).ToString("N0"); NetText.Text = _lines.Sum(x => x.Total).ToString("N0");
    }

    private void ResetLineInputs()
    {
        ProductBox.SelectedItem = null; QtyBox.Text = "1"; PriceBox.Text = "0"; DiscountBox.Text = "0"; DutiesBox.Text = "0";
        VatRateBox.Text = _defaultVatRate.ToString("0.##", CultureInfo.InvariantCulture); SelectTag(VatStatusBox, "STANDARD");
        LineDescriptionBox.Clear(); MatchHintText.Text = string.Empty;
    }

    private static string SelectedTag(ComboBox box) => (box.SelectedItem as ComboBoxItem)?.Tag?.ToString() ?? string.Empty;
    private static void SelectTag(ComboBox box, string tag) { foreach (var item in box.Items.OfType<ComboBoxItem>()) if (string.Equals(item.Tag?.ToString(), tag, StringComparison.OrdinalIgnoreCase)) { box.SelectedItem = item; return; } }
    private static bool TryNumber(string? text, out decimal value)
    {
        var normalized = PersianDate.ToLatinDigits(text ?? string.Empty).Replace(",", string.Empty).Trim();
        return decimal.TryParse(normalized, NumberStyles.Number | NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out value);
    }
}
