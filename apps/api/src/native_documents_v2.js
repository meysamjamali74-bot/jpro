import { pool } from './db.js';
import { requireRole } from './auth.js';

const n = v => Number(v || 0);
const text = v => String(v ?? '').trim();
const fail = (message, status = 400, details = null) => { const e = new Error(message); e.status = status; e.details = details; throw e; };
const wrap = fn => async (req, res) => {
  try { await fn(req, res); }
  catch (e) {
    console.error('native documents v2 error', e);
    res.status(e.status || 400).json({ error: e.message || 'OPERATION_FAILED', details: e.details || undefined });
  }
};

function buildFilters(req, alias, partyAlias, partyColumn) {
  const where = [`${alias}.company_id=?`, `${alias}.is_void=0`];
  const params = [req.user.companyId];
  const q = text(req.query.q);
  const status = text(req.query.status);
  const classification = text(req.query.classification);
  const dateFrom = text(req.query.dateFrom);
  const dateTo = text(req.query.dateTo);
  if (q) {
    const like = `%${q}%`;
    where.push(`(${alias}.invoice_no LIKE ? OR ${partyAlias}.name LIKE ? OR ${alias}.${partyColumn} LIKE ?)`);
    params.push(like, like, like);
  }
  if (status) { where.push(`${alias}.status=?`); params.push(status); }
  if (classification) { where.push(`${alias}.invoice_classification=?`); params.push(classification); }
  if (dateFrom) { where.push(`${alias}.invoice_date>=?`); params.push(dateFrom); }
  if (dateTo) { where.push(`${alias}.invoice_date<=?`); params.push(dateTo); }
  return { sql: where.join(' AND '), params };
}

export function registerNativeDocumentRoutes(app) {
  app.get('/api/native/document-lookups', requireRole(
    'SALES_PERSON', 'SALES_MANAGER', 'WAREHOUSE_MANAGER', 'ACCOUNTANT', 'FINANCE_MANAGER'
  ), wrap(async (req, res) => {
    const c = req.user.companyId;
    const [customers, suppliers, products, warehouses, vatRates] = await Promise.all([
      pool.execute(`SELECT p.id,p.code,p.name,p.national_id,p.economic_code,p.postal_code,
          COALESCE(cp.credit_limit,0) credit_limit,COALESCE(cp.payment_terms_days,0) payment_terms_days
        FROM parties p JOIN party_roles pr ON pr.party_id=p.id AND pr.role_code='CUSTOMER'
        LEFT JOIN customer_profiles cp ON cp.party_id=p.id
        WHERE p.company_id=? AND p.is_deleted=0 ORDER BY p.name LIMIT 1000`, [c]),
      pool.execute(`SELECT p.id,p.code,p.name,p.national_id,p.economic_code,p.postal_code,
          COALESCE(sp.payment_terms_days,0) payment_terms_days,sp.bank_iban
        FROM parties p JOIN party_roles pr ON pr.party_id=p.id AND pr.role_code='SUPPLIER'
        LEFT JOIN supplier_profiles sp ON sp.party_id=p.id
        WHERE p.company_id=? AND p.is_deleted=0 ORDER BY p.name LIMIT 1000`, [c]),
      pool.execute(`SELECT p.id,p.sku,p.name,p.unit,p.product_type,p.sale_price,p.purchase_price,
          p.vat_status,p.default_vat_rate,p.goods_service_id,p.unit_code,
          COALESCE(SUM(ib.on_hand_qty),0) on_hand_qty,
          COALESCE(SUM(ib.reserved_qty),0) reserved_qty,
          COALESCE(SUM(GREATEST(ib.on_hand_qty-ib.reserved_qty-ib.quarantine_qty-ib.damaged_qty,0)),0) available_qty
        FROM products p LEFT JOIN inventory_balances ib ON ib.company_id=p.company_id AND ib.product_id=p.id
        WHERE p.company_id=? AND p.is_deleted=0 AND p.is_active=1
        GROUP BY p.id ORDER BY p.name LIMIT 2000`, [c]),
      pool.execute(`SELECT id,code,name,warehouse_type,allow_negative FROM warehouses
        WHERE company_id=? AND is_active=1 ORDER BY name`, [c]),
      pool.execute(`SELECT tax_code,rate,effective_from,effective_to FROM tax_rates
        WHERE tax_kind='VAT' AND is_active=1 AND (company_id=? OR company_id IS NULL)
        ORDER BY (company_id IS NOT NULL) DESC,effective_from DESC`, [c])
    ]);
    res.json({ customers: customers[0], suppliers: suppliers[0], products: products[0], warehouses: warehouses[0], vatRates: vatRates[0] });
  }));

  app.get('/api/native/sales-invoices', requireRole('SALES_PERSON','SALES_MANAGER','ACCOUNTANT','FINANCE_MANAGER','WAREHOUSE_MANAGER'), wrap(async (req, res) => {
    const { sql, params } = buildFilters(req, 'si', 'p', 'invoice_no');
    const [rows] = await pool.execute(`SELECT si.id,si.invoice_no,si.invoice_date,si.due_date,si.status,
        si.invoice_classification,si.tax_invoice_type,si.tax_status,si.settlement_type,
        si.gross_total,si.discount_total,si.tax_total,si.net_total,si.outstanding_amount,
        si.fulfillment_status,si.warehouse_id,p.name customer,w.name warehouse,si.created_at
      FROM sales_invoices si JOIN parties p ON p.id=si.customer_party_id
      LEFT JOIN warehouses w ON w.id=si.warehouse_id
      WHERE ${sql} ORDER BY si.invoice_date DESC,si.id DESC LIMIT 500`, params);
    const summary = rows.reduce((a, r) => {
      a.count += 1; a.net += n(r.net_total); a.outstanding += n(r.outstanding_amount);
      if (String(r.status).toUpperCase() === 'DRAFT') a.draft += 1;
      return a;
    }, { count: 0, net: 0, outstanding: 0, draft: 0 });
    res.json({ rows, summary });
  }));

  app.get('/api/native/sales-invoices/:id', requireRole('SALES_PERSON','SALES_MANAGER','ACCOUNTANT','FINANCE_MANAGER','WAREHOUSE_MANAGER'), wrap(async (req, res) => {
    const id = Number(req.params.id), c = req.user.companyId;
    const [headers] = await pool.execute(`SELECT si.*,p.name customer,w.name warehouse
      FROM sales_invoices si JOIN parties p ON p.id=si.customer_party_id
      LEFT JOIN warehouses w ON w.id=si.warehouse_id
      WHERE si.id=? AND si.company_id=? AND si.is_void=0`, [id, c]);
    if (!headers.length) fail('فاکتور فروش پیدا نشد.', 404);
    const [lines] = await pool.execute(`SELECT l.*,p.sku,p.name product_name,p.unit
      FROM sales_invoice_lines l JOIN products p ON p.id=l.product_id
      WHERE l.invoice_id=? ORDER BY l.id`, [id]);
    res.json({ invoice: headers[0], lines });
  }));

  app.put('/api/native/sales-invoices/:id/warehouse', requireRole('SALES_PERSON','SALES_MANAGER','WAREHOUSE_MANAGER'), wrap(async (req, res) => {
    const id = Number(req.params.id), warehouseId = Number(req.body?.warehouseId), c = req.user.companyId;
    if (!warehouseId) fail('انتخاب انبار الزامی است.');
    const [wh] = await pool.execute('SELECT id FROM warehouses WHERE id=? AND company_id=? AND is_active=1', [warehouseId, c]);
    if (!wh.length) fail('انبار انتخاب‌شده معتبر نیست.', 422);
    const [r] = await pool.execute(`UPDATE sales_invoices SET warehouse_id=?
      WHERE id=? AND company_id=? AND is_void=0 AND posted_at IS NULL AND status IN ('DRAFT','WAITING_APPROVAL','APPROVED')`, [warehouseId, id, c]);
    if (!r.affectedRows) fail('انبار فقط قبل از ثبت قطعی فاکتور قابل تغییر است.', 422);
    res.json({ ok: true, warehouseId });
  }));

  app.get('/api/native/purchase-invoices', requireRole('ACCOUNTANT','FINANCE_MANAGER','WAREHOUSE_MANAGER'), wrap(async (req, res) => {
    const { sql, params } = buildFilters(req, 'pi', 'p', 'supplier_invoice_no');
    const [rows] = await pool.execute(`SELECT pi.id,pi.invoice_no,pi.supplier_invoice_no,pi.invoice_date,pi.due_date,pi.status,
        pi.invoice_classification,pi.tax_invoice_type,pi.tax_unique_no,pi.settlement_type,pi.purchase_kind,
        pi.gross_total,pi.discount_total,pi.tax_total,pi.other_duties_total,pi.net_total,pi.outstanding_amount,
        p.name supplier,po.po_no,gr.receipt_no,
        (SELECT COUNT(*) FROM purchase_match_results mr WHERE mr.purchase_invoice_id=pi.id AND mr.status='OPEN') open_match_count,
        pi.created_at
      FROM purchase_invoices pi JOIN parties p ON p.id=pi.supplier_party_id
      LEFT JOIN purchase_orders po ON po.id=pi.purchase_order_id
      LEFT JOIN goods_receipts gr ON gr.id=pi.goods_receipt_id
      WHERE ${sql} ORDER BY pi.invoice_date DESC,pi.id DESC LIMIT 500`, params);
    const summary = rows.reduce((a, r) => {
      a.count += 1; a.net += n(r.net_total); a.outstanding += n(r.outstanding_amount);
      if (String(r.status).toUpperCase() === 'MATCH_EXCEPTION') a.exceptions += 1;
      return a;
    }, { count: 0, net: 0, outstanding: 0, exceptions: 0 });
    res.json({ rows, summary });
  }));

  app.get('/api/native/purchase-invoices/:id', requireRole('ACCOUNTANT','FINANCE_MANAGER','WAREHOUSE_MANAGER'), wrap(async (req, res) => {
    const id = Number(req.params.id), c = req.user.companyId;
    const [headers] = await pool.execute(`SELECT pi.*,p.name supplier,po.po_no,gr.receipt_no
      FROM purchase_invoices pi JOIN parties p ON p.id=pi.supplier_party_id
      LEFT JOIN purchase_orders po ON po.id=pi.purchase_order_id
      LEFT JOIN goods_receipts gr ON gr.id=pi.goods_receipt_id
      WHERE pi.id=? AND pi.company_id=? AND pi.is_void=0`, [id, c]);
    if (!headers.length) fail('فاکتور خرید پیدا نشد.', 404);
    const [lines] = await pool.execute(`SELECT l.*,p.sku,p.name product_name,p.unit
      FROM purchase_invoice_lines l LEFT JOIN products p ON p.id=l.product_id
      WHERE l.invoice_id=? ORDER BY l.id`, [id]);
    const [matches] = await pool.execute(`SELECT * FROM purchase_match_results
      WHERE purchase_invoice_id=? AND company_id=? ORDER BY FIELD(severity,'CRITICAL','HIGH','WARNING','INFO'),id`, [id, c]);
    res.json({ invoice: headers[0], lines, matches });
  }));
}
