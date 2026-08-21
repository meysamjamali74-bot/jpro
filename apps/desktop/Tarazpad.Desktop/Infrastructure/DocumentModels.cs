using System.Text.Json;

namespace Tarazpad.Desktop.Infrastructure;

public sealed class PartyLookupItem
{
    public long Id { get; init; }
    public string Code { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public decimal CreditLimit { get; init; }
    public int PaymentTermsDays { get; init; }
    public string Display => string.IsNullOrWhiteSpace(Code) ? Name : $"{Code} - {Name}";
}

public sealed class WarehouseLookupItem
{
    public long Id { get; init; }
    public string Code { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public string WarehouseType { get; init; } = string.Empty;
    public string Display => string.IsNullOrWhiteSpace(Code) ? Name : $"{Code} - {Name}";
}

public sealed class ProductLookupItem
{
    public long Id { get; init; }
    public string Sku { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public string Unit { get; init; } = string.Empty;
    public string ProductType { get; init; } = "GOODS";
    public decimal SalePrice { get; init; }
    public decimal PurchasePrice { get; init; }
    public string VatStatus { get; init; } = "STANDARD";
    public decimal VatRate { get; init; }
    public string GoodsServiceId { get; init; } = string.Empty;
    public string UnitCode { get; init; } = string.Empty;
    public decimal OnHandQty { get; init; }
    public decimal ReservedQty { get; init; }
    public decimal AvailableQty { get; init; }
    public string Display => $"{Sku} - {Name}";
}

public sealed class ProcurementLookupItem
{
    public long Id { get; init; }
    public string Number { get; init; } = string.Empty;
    public long SupplierPartyId { get; init; }
    public long? PurchaseOrderId { get; init; }
    public string Supplier { get; init; } = string.Empty;
    public string Status { get; init; } = string.Empty;
    public string Display => $"{Number} - {Supplier} - {UiText.Display(Status)}";
}

public sealed class InvoiceLineDraft
{
    public long ProductId { get; set; }
    public string Sku { get; set; } = string.Empty;
    public string ProductName { get; set; } = string.Empty;
    public string Unit { get; set; } = string.Empty;
    public string ProductType { get; set; } = "GOODS";
    public decimal Qty { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal DiscountAmount { get; set; }
    public string VatStatus { get; set; } = "STANDARD";
    public decimal VatRate { get; set; }
    public decimal OtherDutiesAmount { get; set; }
    public string Description { get; set; } = string.Empty;
    public string GoodsServiceId { get; set; } = string.Empty;
    public string UnitCode { get; set; } = string.Empty;
    public long? PurchaseOrderLineId { get; set; }
    public long? GoodsReceiptLineId { get; set; }
    public decimal Gross => Math.Round(Qty * UnitPrice, 2);
    public decimal Taxable => Math.Max(0, Gross - DiscountAmount);
    public decimal Tax => VatStatus is "EXEMPT" or "ZERO" ? 0 : Math.Round(Taxable * VatRate / 100m, 0);
    public decimal Total => Taxable + Tax + OtherDutiesAmount;
    public string VatDisplay => UiText.Display(VatStatus);
}

public static class DocumentJson
{
    public static long Long(JsonElement element, string name)
        => element.TryGetProperty(name, out var v) && v.ValueKind != JsonValueKind.Null && v.TryGetInt64(out var x) ? x : 0;

    public static long? NullableLong(JsonElement element, string name)
        => element.TryGetProperty(name, out var v) && v.ValueKind != JsonValueKind.Null && v.TryGetInt64(out var x) ? x : null;

    public static decimal Decimal(JsonElement element, string name)
    {
        if (!element.TryGetProperty(name, out var v) || v.ValueKind == JsonValueKind.Null) return 0;
        if (v.TryGetDecimal(out var d)) return d;
        return decimal.TryParse(v.ToString(), out d) ? d : 0;
    }

    public static string String(JsonElement element, string name)
        => element.TryGetProperty(name, out var v) && v.ValueKind != JsonValueKind.Null ? v.ToString() : string.Empty;

    public static IReadOnlyList<PartyLookupItem> Parties(JsonElement root, string property)
        => root.GetProperty(property).EnumerateArray().Select(x => new PartyLookupItem
        {
            Id = Long(x, "id"), Code = String(x, "code"), Name = String(x, "name"),
            CreditLimit = Decimal(x, "credit_limit"), PaymentTermsDays = (int)Long(x, "payment_terms_days")
        }).ToList();

    public static IReadOnlyList<WarehouseLookupItem> Warehouses(JsonElement root)
        => root.GetProperty("warehouses").EnumerateArray().Select(x => new WarehouseLookupItem
        {
            Id = Long(x, "id"), Code = String(x, "code"), Name = String(x, "name"), WarehouseType = String(x, "warehouse_type")
        }).ToList();

    public static IReadOnlyList<ProductLookupItem> Products(JsonElement root)
        => root.GetProperty("products").EnumerateArray().Select(x => new ProductLookupItem
        {
            Id = Long(x, "id"), Sku = String(x, "sku"), Name = String(x, "name"), Unit = String(x, "unit"),
            ProductType = String(x, "product_type"), SalePrice = Decimal(x, "sale_price"), PurchasePrice = Decimal(x, "purchase_price"),
            VatStatus = string.IsNullOrWhiteSpace(String(x, "vat_status")) ? "STANDARD" : String(x, "vat_status"),
            VatRate = Decimal(x, "default_vat_rate"), GoodsServiceId = String(x, "goods_service_id"), UnitCode = String(x, "unit_code"),
            OnHandQty = Decimal(x, "on_hand_qty"), ReservedQty = Decimal(x, "reserved_qty"), AvailableQty = Decimal(x, "available_qty")
        }).ToList();

    public static IReadOnlyList<ProcurementLookupItem> PurchaseOrders(JsonElement root)
        => root.GetProperty("purchaseOrders").EnumerateArray().Select(x => new ProcurementLookupItem
        {
            Id = Long(x, "id"), Number = String(x, "po_no"), SupplierPartyId = Long(x, "supplier_party_id"),
            Supplier = String(x, "supplier"), Status = String(x, "status")
        }).ToList();

    public static IReadOnlyList<ProcurementLookupItem> GoodsReceipts(JsonElement root)
        => root.GetProperty("goodsReceipts").EnumerateArray().Select(x => new ProcurementLookupItem
        {
            Id = Long(x, "id"), Number = String(x, "receipt_no"), SupplierPartyId = Long(x, "supplier_party_id"),
            PurchaseOrderId = NullableLong(x, "purchase_order_id"), Supplier = String(x, "supplier"), Status = String(x, "status")
        }).ToList();
}
