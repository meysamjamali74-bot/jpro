import { registerYearEndOpeningOverrideV7 } from './year_end_opening_override_v7.js';
import { registerFiscalScopeReportingOverrideV7 } from './fiscal_scope_reporting_override_v7.js';
import { registerHistoricalReportingOverrideV7 } from './historical_reporting_override_v7.js';
import { registerStatementRenderOverrideV7 } from './statement_render_override_v7.js';
import { registerYearEndCalculateOverrideV7 } from './year_end_calculate_override_v7.js';
import { registerYearEndV7Routes } from './year_end_v7.js';
import { registerStatementDesignerV7Routes } from './statement_designer_v7.js';
import { registerComplianceV7Routes } from './compliance_v7.js';
import { registerFinanceReportingOverridesV6 } from './finance_reporting_overrides_v6.js';
import { registerFinanceReportingV6Routes } from './finance_reporting_v6.js';
import { fieldPolicyMiddleware } from './field_policy_middleware.js';
import { registerBiV5Routes } from './bi_v5.js';
import { registerFxRevaluationPostV5Routes } from './fx_revaluation_post_v5.js';
import { registerFxV5Routes } from './fx_v5.js';
import { registerSecurityV5Routes } from './security_v5.js';
import { registerMaintenanceV5Routes } from './maintenance_v5.js';
import { registerPayrollCommissionV5Routes } from './payroll_commission_v5.js';
import { registerConsolidationV5Routes } from './consolidation_v5.js';
import { registerWmsFulfillmentV5Routes } from './wms_fulfillment_v5.js';
import { registerWmsIssueV5Routes } from './wms_issue_v5.js';
import { registerSalesCostPolicyV5Routes } from './sales_cost_policy_v5.js';
import { registerSalesV5Routes } from './sales_v5.js';
import { registerCampaignV4Routes } from './campaign_v4.js';
import { registerOfficeV4ExtraRoutes } from './office_v4_extra.js';
import { registerBpmV4Routes } from './bpm_v4.js';
import { registerLoyaltyV4Routes } from './loyalty_v4.js';
import { registerCrmV4ExtraRoutes } from './crm_v4_extra.js';
import { registerCrmV4Routes } from './crm_v4.js';
import { registerFinanceV3ExtraRoutes } from './finance_v3_extra.js';
import { registerFinanceV3ControlRoutes } from './finance_v3_controls.js';
import { pool } from './db.js';
import { requireRole } from './auth.js';
import { registerPurchaseIranRoutes } from './purchase_iran.js';
import { registerPurchaseContextRoutes } from './purchase_context.js';
import { registerPayrollIranRoutes } from './payroll_iran.js';
import { registerPayrollExtraRoutes } from './payroll_extra.js';
import { registerTreasuryV2Routes } from './treasury_v2.js';
import { registerBankImportV2Routes } from './bank_import_v2.js';
import { registerSalesCostingV2Routes } from './sales_costing_v2.js';
import { registerDistributionV2Routes } from './distribution_v2.js';
import { registerCommissionV2Routes } from './commission_v2.js';
import { registerAdminV2Routes } from './admin_v2.js';

const n=v=>Number(v||0),text=v=>String(v??'').trim();
const fail=(message,status=400,details=null)=>{const e=new Error(message);e.status=status;e.details=details;throw e};
const wrap=fn=>async(req,res)=>{try{await fn(req,res)}catch(e){console.error('iran extension error',e);res.status(e.status||400).json({error:e.message,details:e.details||undefined})}};
async function audit(req,action,type,id,payload){try{await pool.execute(`INSERT INTO audit_logs(company_id,user_id,action,entity_type,entity_id,after_json,ip_address,user_agent) VALUES (?,?,?,?,?,?,?,?)`,[req.user.companyId,Number(req.user.sub),action,type,id,JSON.stringify(payload||{}),req.ip,req.headers['user-agent']||null])}catch{}}

export function registerIranExtensionRoutes(app){
  app.use(fieldPolicyMiddleware);

  // Enterprise 1.7 final deterministic control order.
  registerFiscalScopeReportingOverrideV7(app);
  registerHistoricalReportingOverrideV7(app);
  registerStatementRenderOverrideV7(app);
  registerYearEndCalculateOverrideV7(app);
  registerYearEndOpeningOverrideV7(app);
  registerYearEndV7Routes(app);
  registerStatementDesignerV7Routes(app);
  registerComplianceV7Routes(app);

  // Enterprise 1.7 deterministic control order.


  // Historical performance statements must exclude system year-end closing entries.


  // Enterprise 1.7: year-end, financial statement designer and statutory compliance.

  // Financial reporting overrides precede the underlying reporting routes.
  registerFinanceReportingOverridesV6(app);
  registerFinanceReportingV6Routes(app);

  // WMS/valuation overrides must precede older fulfillment routes.
  registerWmsFulfillmentV5Routes(app);
  registerWmsIssueV5Routes(app);
  registerSalesCostPolicyV5Routes(app);
  registerSalesV5Routes(app);
  registerPayrollCommissionV5Routes(app);

  registerBiV5Routes(app);
  registerFxRevaluationPostV5Routes(app);
  registerFxV5Routes(app);
  registerSecurityV5Routes(app);
  registerMaintenanceV5Routes(app);
  registerConsolidationV5Routes(app);

  registerFinanceV3ControlRoutes(app);
  registerFinanceV3ExtraRoutes(app);
  registerCrmV4Routes(app);
  registerCrmV4ExtraRoutes(app);
  registerLoyaltyV4Routes(app);
  registerBpmV4Routes(app);
  registerOfficeV4ExtraRoutes(app);
  registerCampaignV4Routes(app);

  registerAdminV2Routes(app);
  registerTreasuryV2Routes(app);
  registerBankImportV2Routes(app);
  registerSalesCostingV2Routes(app);
  registerDistributionV2Routes(app);
  registerCommissionV2Routes(app);
  registerPayrollIranRoutes(app);
  registerPayrollExtraRoutes(app);
  registerPurchaseContextRoutes(app);
  registerPurchaseIranRoutes(app);

  app.get('/api/iran/products',wrap(async(req,res)=>{
    const q=text(req.query.q),vat=text(req.query.vatStatus),type=text(req.query.productType),active=text(req.query.active);
    const where=['p.company_id=?','p.is_deleted=0'],params=[req.user.companyId];
    if(q){const like=`%${q}%`;where.push('(p.name LIKE ? OR p.sku LIKE ? OR p.barcode LIKE ? OR p.goods_service_id LIKE ?)');params.push(like,like,like,like)}
    if(vat){where.push('p.vat_status=?');params.push(vat)}
    if(type){where.push('p.product_type=?');params.push(type)}
    if(active!==''){where.push('p.is_active=?');params.push(active==='1'||active==='true'?1:0)}
    const [rows]=await pool.execute(`SELECT p.*,COALESCE(SUM(ib.on_hand_qty),0) on_hand_qty,COALESCE(SUM(ib.reserved_qty),0) reserved_qty,COALESCE(SUM(ib.quarantine_qty),0) quarantine_qty,COALESCE(SUM(ib.damaged_qty),0) damaged_qty FROM products p LEFT JOIN inventory_balances ib ON ib.product_id=p.id AND ib.company_id=p.company_id WHERE ${where.join(' AND ')} GROUP BY p.id ORDER BY p.id DESC LIMIT 500`,params);
    res.json(rows);
  }));

  app.post('/api/iran/products',requireRole('WAREHOUSE_MANAGER','SALES_MANAGER','FINANCE_MANAGER'),wrap(async(req,res)=>{
    const b=req.body||{};
    if(!text(b.sku)||!text(b.name))fail('کد کالا و نام کالا/خدمت الزامی است.');
    const [r]=await pool.execute(`INSERT INTO products(company_id,sku,barcode,name,brand,category,unit,sale_price,purchase_price,min_stock,reorder_point,track_batch,track_expiry,catch_weight,is_active,goods_service_id,unit_code,vat_status,default_vat_rate,product_type) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,[req.user.companyId,b.sku,b.barcode||null,b.name,b.brand||null,b.category||null,b.unit||'عدد',n(b.salePrice),n(b.purchasePrice),n(b.minStock),n(b.reorderPoint),b.trackBatch?1:0,b.trackExpiry?1:0,b.catchWeight?1:0,1,b.goodsServiceId||null,b.unitCode||null,b.vatStatus||'STANDARD',b.defaultVatRate==null?null:n(b.defaultVatRate),b.productType||'GOODS']);
    await audit(req,'CREATE','product',r.insertId,b);
    res.status(201).json({id:r.insertId});
  }));

  app.put('/api/iran/products/:id',requireRole('WAREHOUSE_MANAGER','SALES_MANAGER','FINANCE_MANAGER'),wrap(async(req,res)=>{
    const id=Number(req.params.id),b=req.body||{};
    const [old]=await pool.execute('SELECT * FROM products WHERE id=? AND company_id=?',[id,req.user.companyId]);
    if(!old.length)fail('کالا/خدمت پیدا نشد.',404);
    const o=old[0];
    await pool.execute(`UPDATE products SET sku=?,barcode=?,name=?,brand=?,category=?,unit=?,sale_price=?,purchase_price=?,min_stock=?,reorder_point=?,goods_service_id=?,unit_code=?,vat_status=?,default_vat_rate=?,product_type=?,track_batch=?,track_expiry=?,catch_weight=?,is_active=? WHERE id=? AND company_id=?`,[b.sku??o.sku,b.barcode??o.barcode,b.name??o.name,b.brand??o.brand,b.category??o.category,b.unit??o.unit,b.salePrice==null?o.sale_price:n(b.salePrice),b.purchasePrice==null?o.purchase_price:n(b.purchasePrice),b.minStock==null?o.min_stock:n(b.minStock),b.reorderPoint==null?o.reorder_point:n(b.reorderPoint),b.goodsServiceId??o.goods_service_id,b.unitCode??o.unit_code,b.vatStatus??o.vat_status,b.defaultVatRate===undefined?o.default_vat_rate:(b.defaultVatRate==null?null:n(b.defaultVatRate)),b.productType??o.product_type,b.trackBatch==null?o.track_batch:(b.trackBatch?1:0),b.trackExpiry==null?o.track_expiry:(b.trackExpiry?1:0),b.catchWeight==null?o.catch_weight:(b.catchWeight?1:0),b.isActive==null?o.is_active:(b.isActive?1:0),id,req.user.companyId]);
    await audit(req,'UPDATE','product',id,b);
    res.json({ok:true});
  }));

  app.get('/api/iran/sales-invoices',wrap(async(req,res)=>{
    const q=text(req.query.q),status=text(req.query.status),classification=text(req.query.classification),dateFrom=text(req.query.dateFrom),dateTo=text(req.query.dateTo);
    const page=Math.max(1,n(req.query.page)||1),pageSize=Math.min(200,Math.max(10,n(req.query.pageSize)||50)),offset=(page-1)*pageSize;
    const where=['si.company_id=?','si.is_void=0'],params=[req.user.companyId];
    if(q){const like=`%${q}%`;where.push('(si.invoice_no LIKE ? OR p.name LIKE ? OR p.economic_code LIKE ? OR si.tax_unique_no LIKE ?)');params.push(like,like,like,like)}
    if(status){where.push('si.status=?');params.push(status)}
    if(classification){where.push('si.invoice_classification=?');params.push(classification)}
    if(dateFrom){where.push('si.invoice_date>=?');params.push(dateFrom)}
    if(dateTo){where.push('si.invoice_date<=?');params.push(dateTo)}
    const whereSql=where.join(' AND ');
    const [[cnt]]=await pool.execute(`SELECT COUNT(*) total FROM sales_invoices si JOIN parties p ON p.id=si.customer_party_id WHERE ${whereSql}`,params);
    const [rows]=await pool.execute(`SELECT si.id,si.invoice_no,si.invoice_date,si.due_date,si.customer_party_id,p.name customer,p.economic_code customer_economic_code,si.invoice_classification,si.tax_invoice_type,si.settlement_type,si.tax_status,si.status,si.gross_total,si.discount_total,si.tax_total,si.net_total,si.outstanding_amount,si.tax_unique_no,si.salesperson_user_id,si.route_id,si.posted_at FROM sales_invoices si JOIN parties p ON p.id=si.customer_party_id WHERE ${whereSql} ORDER BY si.invoice_date DESC,si.id DESC LIMIT ${pageSize} OFFSET ${offset}`,params);
    res.json({rows,total:n(cnt.total),page,pageSize});
  }));
}
