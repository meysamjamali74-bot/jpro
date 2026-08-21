using System.Collections.ObjectModel;
using System.Globalization;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using Tarazpad.Desktop.Infrastructure;

namespace Tarazpad.Desktop.Views;

public partial class SalesInvoiceEditorWindow : Window
{
    private readonly ObservableCollection<InvoiceLineDraft> _lines = new();
    private IReadOnlyList<ProductLookupItem> _products = Array.Empty<ProductLookupItem>();
    private decimal _defaultVatRate;

    public SalesInvoiceEditorWindow()
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
            ErrorText.Text = "در حال دریافت اطلاعات پایه...";
            var root = await App.Api.GetJsonAsync("api/native/document-lookups");
            CustomerBox.ItemsSource = DocumentJson.Parties(root, "customers");
            WarehouseBox.ItemsSource = DocumentJson.Warehouses(root);
            _products = DocumentJson.Products(root);
            ProductBox.ItemsSource = _products;
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

    private void ProductBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (ProductBox.SelectedItem is not ProductLookupItem p) return;
        PriceBox.Text = p.SalePrice.ToString("0.##", CultureInfo.InvariantCulture);
        LineDescriptionBox.Text = p.Name;
        SelectTag(VatStatusBox, string.IsNullOrWhiteSpace(p.VatStatus) ? "STANDARD" : p.VatStatus);
        VatRateBox.Text = (p.VatRate > 0 ? p.VatRate : _defaultVatRate).ToString("0.##", CultureInfo.InvariantCulture);
        StockText.Text = p.ProductType == "SERVICE"
            ? "خدمت • بدون کنترل موجودی"
            : $"موجودی قابل فروش: {p.AvailableQty:N2} {p.Unit}  |  موجودی کل: {p.OnHandQty:N2}";
    }

    private void CustomerBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (CustomerBox.SelectedItem is not PartyLookupItem customer) { CreditInfoText.Text = "—"; return; }
        CreditInfoText.Text = $"سقف {customer.CreditLimit:N0} • مهلت {customer.PaymentTermsDays} روز";
        if (customer.PaymentTermsDays > 0 && PersianDate.TryToGregorian(InvoiceDateBox.Text, out var invoiceDate))
            DueDateBox.Text = PersianDate.FromGregorian(invoiceDate.AddDays(customer.PaymentTermsDays));
    }

    private void ClassificationBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (!IsLoaded) return;
        TaxTypeBox.IsEnabled = SelectedTag(ClassificationBox) == "OFFICIAL";
    }

    private void SettlementBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (!IsLoaded) return;
        CashAmountBox.IsEnabled = SelectedTag(SettlementBox) == "MIXED";
        if (!CashAmountBox.IsEnabled) CashAmountBox.Text = "0";
    }

    private void AddLine_Click(object sender, RoutedEventArgs e)
    {
        ErrorText.Text = string.Empty;
        if (ProductBox.SelectedItem is not ProductLookupItem product) { ErrorText.Text = "کالا یا خدمت را انتخاب کنید."; return; }
        if (!TryNumber(QtyBox.Text, out var qty) || qty <= 0) { ErrorText.Text = "مقدار ردیف باید بیشتر از صفر باشد."; return; }
        if (!TryNumber(PriceBox.Text, out var price) || price < 0) { ErrorText.Text = "قیمت واحد معتبر نیست."; return; }
        TryNumber(DiscountBox.Text, out var discount);
        TryNumber(VatRateBox.Text, out var vatRate);
        TryNumber(DutiesBox.Text, out var duties);
        var gross = qty * price;
        if (discount < 0 || discount > gross) { ErrorText.Text = "تخفیف ردیف نمی‌تواند بیشتر از مبلغ ناخالص باشد."; return; }
        if (duties < 0 || vatRate < 0) { ErrorText.Text = "مالیات و عوارض نمی‌تواند منفی باشد."; return; }

        var vatStatus = SelectedTag(VatStatusBox);
        _lines.Add(new InvoiceLineDraft
        {
            ProductId = product.Id, Sku = product.Sku, ProductName = product.Name, Unit = product.Unit,
            ProductType = product.ProductType, Qty = qty, UnitPrice = price, DiscountAmount = discount,
            VatStatus = vatStatus, VatRate = vatStatus is "EXEMPT" or "ZERO" ? 0 : vatRate,
            OtherDutiesAmount = duties, Description = string.IsNullOrWhiteSpace(LineDescriptionBox.Text) ? product.Name : LineDescriptionBox.Text.Trim(),
            GoodsServiceId = product.GoodsServiceId, UnitCode = product.UnitCode
        });
        ResetLineInputs();
        UpdateTotals();
    }

    private void RemoveLine_Click(object sender, RoutedEventArgs e)
    {
        if (LinesGrid.SelectedItem is InvoiceLineDraft line) _lines.Remove(line);
        UpdateTotals();
    }

    private async void Save_Click(object sender, RoutedEventArgs e)
    {
        ErrorText.Text = string.Empty;
        if (CustomerBox.SelectedItem is not PartyLookupItem customer) { ErrorText.Text = "انتخاب مشتری الزامی است."; return; }
        if (_lines.Count == 0) { ErrorText.Text = "حداقل یک ردیف کالا یا خدمت ثبت کنید."; return; }
        if (!PersianDate.TryToGregorian(InvoiceDateBox.Text, out var invoiceDate)) { ErrorText.Text = "تاریخ فاکتور شمسی معتبر نیست."; return; }
        DateTime? dueDate = null;
        if (!string.IsNullOrWhiteSpace(DueDateBox.Text))
        {
            if (!PersianDate.TryToGregorian(DueDateBox.Text, out var parsedDue)) { ErrorText.Text = "تاریخ سررسید شمسی معتبر نیست."; return; }
            dueDate = parsedDue;
        }
        var goods = _lines.Any(x => x.ProductType != "SERVICE");
        if (goods && WarehouseBox.SelectedItem is not WarehouseLookupItem) { ErrorText.Text = "برای فاکتور دارای کالا، انتخاب انبار خروج الزامی است."; return; }
        var classification = SelectedTag(ClassificationBox);
        if (classification == "OFFICIAL" && _lines.Any(x => string.IsNullOrWhiteSpace(x.GoodsServiceId) || string.IsNullOrWhiteSpace(x.UnitCode)))
        {
            ErrorText.Text = "برای فاکتور رسمی، شناسه کالا/خدمت و کد واحد سنجش باید در اطلاعات پایه کالاها تکمیل باشد.";
            return;
        }
        var settlement = SelectedTag(SettlementBox);
        var net = _lines.Sum(x => x.Total);
        TryNumber(CashAmountBox.Text, out var cashAmount);
        if (settlement == "MIXED" && (cashAmount < 0 || cashAmount > net)) { ErrorText.Text = "مبلغ نقدی تسویه ترکیبی باید بین صفر و مبلغ خالص فاکتور باشد."; return; }

        SaveButton.IsEnabled = false;
        try
        {
            var payload = new
            {
                customerPartyId = customer.Id,
                invoiceDate = invoiceDate.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
                dueDate = dueDate?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
                invoiceClassification = classification,
                taxInvoiceType = classification == "OFFICIAL" ? SelectedTag(TaxTypeBox) : null,
                taxInvoicePattern = classification == "OFFICIAL" ? "SALE" : null,
                settlementType = settlement,
                cashAmount = settlement == "MIXED" ? cashAmount : 0,
                notes = string.IsNullOrWhiteSpace(NotesBox.Text) ? null : NotesBox.Text.Trim(),
                lines = _lines.Select(x => new
                {
                    productId = x.ProductId, qty = x.Qty, unitPrice = x.UnitPrice, discountAmount = x.DiscountAmount,
                    vatStatus = x.VatStatus, vatRate = x.VatRate, otherDutiesAmount = x.OtherDutiesAmount,
                    description = x.Description, goodsServiceId = x.GoodsServiceId, unitCode = x.UnitCode
                }).ToArray()
            };
            var result = await App.Api.SendJsonAsync(HttpMethod.Post, "api/iran/sales-invoices", payload);
            var id = DocumentJson.Long(result, "id");
            if (id <= 0) throw new InvalidOperationException("شناسه فاکتور از سرور دریافت نشد.");
            if (WarehouseBox.SelectedItem is WarehouseLookupItem warehouse)
                await App.Api.SendJsonAsync(HttpMethod.Put, $"api/native/sales-invoices/{id}/warehouse", new { warehouseId = warehouse.Id });
            var invoiceNo = DocumentJson.String(result, "invoiceNo");
            MessageBox.Show($"فاکتور {invoiceNo} با موفقیت به‌صورت پیش‌نویس ثبت شد.", "ترازپاد", MessageBoxButton.OK, MessageBoxImage.Information);
            DialogResult = true;
            Close();
        }
        catch (Exception ex)
        {
            ErrorText.Text = ex.Message;
            SaveButton.IsEnabled = true;
        }
    }

    private void UpdateTotals()
    {
        GrossText.Text = _lines.Sum(x => x.Gross).ToString("N0");
        DiscountText.Text = _lines.Sum(x => x.DiscountAmount).ToString("N0");
        TaxText.Text = _lines.Sum(x => x.Tax).ToString("N0");
        DutiesText.Text = _lines.Sum(x => x.OtherDutiesAmount).ToString("N0");
        NetText.Text = _lines.Sum(x => x.Total).ToString("N0");
    }

    private void ResetLineInputs()
    {
        ProductBox.SelectedItem = null;
        QtyBox.Text = "1"; PriceBox.Text = "0"; DiscountBox.Text = "0"; DutiesBox.Text = "0";
        VatRateBox.Text = _defaultVatRate.ToString("0.##", CultureInfo.InvariantCulture);
        SelectTag(VatStatusBox, "STANDARD");
        LineDescriptionBox.Clear(); StockText.Text = string.Empty;
    }

    private static string SelectedTag(ComboBox box) => (box.SelectedItem as ComboBoxItem)?.Tag?.ToString() ?? string.Empty;
    private static void SelectTag(ComboBox box, string tag)
    {
        foreach (var item in box.Items.OfType<ComboBoxItem>()) if (string.Equals(item.Tag?.ToString(), tag, StringComparison.OrdinalIgnoreCase)) { box.SelectedItem = item; return; }
    }
    private static bool TryNumber(string? text, out decimal value)
    {
        var normalized = PersianDate.ToLatinDigits(text ?? string.Empty).Replace(",", string.Empty).Trim();
        return decimal.TryParse(normalized, NumberStyles.Number | NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out value);
    }
}
