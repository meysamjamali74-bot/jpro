import { pool, withTransaction } from './db.js';
import { requireRole } from './auth.js';
const txt=v=>String(v??'').trim(),n=v=>Number(v||0);
const fail=(m,s=400)=>{const e=new Error(m);e.status=s;throw e};
const wrap=fn=>async(req,res)=>{try{await fn(req,res)}catch(e){console.error('commercial compat v8',e);res.status(e.status||400).json({error:e.message})}};
const read=requireRole('SUPER_ADMIN','FINANCE_MANAGER','ACCOUNTANT','SALES_MANAGER','WAREHOUSE_MANAGER','PURCHASE_MANAGER','LOGISTICS_MANAGER');
const master=requireRole('SUPER_ADMIN','FINANCE_MANAGER','SALES_MANAGER','WAREHOUSE_MANAGER','PURCHASE_MANAGER');

export function registerCommercialCompatV8Routes(app){
  // Party profile/detail routes are intentionally owned by commercial_master_v8.
  // This compatibility layer only keeps service-as-product endpoints that are not
  // duplicated there, preventing legacy column mappings from shadowing v1.8 schema.
  app.get('/api/iran/master/services',read,wrap(async(req,res)=>{
    const q=`%${txt(req.query.q)}%`;
    const [rows]=await pool.execute(`SELECT p.id,p.sku code,p.name,p.unit,p.sale_price,p.goods_service_id,p.unit_code,p.vat_status,p.default_vat_rate,p.is_active,sp.commission_pct,sp.revenue_account_id,a.code revenue_account_code,a.title revenue_account_title,sp.estimated_duration_minutes,sp.service_notes FROM products p LEFT JOIN service_profiles sp ON sp.product_id=p.id LEFT JOIN accounts a ON a.id=sp.revenue_account_id WHERE p.company_id=? AND p.is_deleted=0 AND p.product_type='SERVICE' AND (?='%%' OR p.name LIKE ? OR p.sku LIKE ?) ORDER BY p.name`,[req.user.companyId,q,q,q]);
    res.json(rows);
  }));

  app.post('/api/iran/master/services',master,wrap(async(req,res)=>{
    const b=req.body||{};
    if(!txt(b.code)||!txt(b.name))fail('کد و نام خدمت الزامی است.');
    const id=await withTransaction(async conn=>{
      const [r]=await conn.execute(`INSERT INTO products(company_id,sku,name,unit,sale_price,goods_service_id,unit_code,vat_status,default_vat_rate,purchase_price,product_type,is_active) VALUES (?,?,?,?,?,?,?,?,?,0,'SERVICE',1)`,[req.user.companyId,txt(b.code),txt(b.name),txt(b.unit)||'عدد',n(b.salePrice),txt(b.goodsServiceId)||null,txt(b.unitCode)||null,b.vatStatus||'STANDARD',b.defaultVatRate==null?null:n(b.defaultVatRate)]);
      await conn.execute(`INSERT INTO service_profiles(product_id,commission_pct,revenue_account_id,estimated_duration_minutes,service_notes) VALUES (?,?,?,?,?)`,[r.insertId,n(b.commissionPct),b.revenueAccountId||null,b.durationMinutes==null?null:Number(b.durationMinutes),txt(b.notes)||null]);
      if(b.groupId)await conn.execute('INSERT INTO product_group_members(product_id,group_id,is_primary) VALUES (?,?,1)',[r.insertId,Number(b.groupId)]);
      return r.insertId;
    });
    res.status(201).json({id});
  }));

  app.put('/api/iran/master/services/:id',master,wrap(async(req,res)=>{
    const id=Number(req.params.id),b=req.body||{};
    await withTransaction(async conn=>{
      const [p]=await conn.execute("SELECT id FROM products WHERE id=? AND company_id=? AND product_type='SERVICE' FOR UPDATE",[id,req.user.companyId]);
      if(!p.length)fail('خدمت پیدا نشد.',404);
      await conn.execute(`UPDATE products SET name=COALESCE(?,name),unit=COALESCE(?,unit),sale_price=COALESCE(?,sale_price),goods_service_id=COALESCE(?,goods_service_id),unit_code=COALESCE(?,unit_code),vat_status=COALESCE(?,vat_status),default_vat_rate=COALESCE(?,default_vat_rate),is_active=COALESCE(?,is_active) WHERE id=?`,[b.name??null,b.unit??null,b.salePrice==null?null:n(b.salePrice),b.goodsServiceId??null,b.unitCode??null,b.vatStatus??null,b.defaultVatRate==null?null:n(b.defaultVatRate),b.isActive==null?null:(b.isActive?1:0),id]);
      await conn.execute(`INSERT INTO service_profiles(product_id,commission_pct,revenue_account_id,estimated_duration_minutes,service_notes) VALUES (?,?,?,?,?) ON DUPLICATE KEY UPDATE commission_pct=VALUES(commission_pct),revenue_account_id=VALUES(revenue_account_id),estimated_duration_minutes=VALUES(estimated_duration_minutes),service_notes=VALUES(service_notes)`,[id,n(b.commissionPct),b.revenueAccountId||null,b.durationMinutes==null?null:Number(b.durationMinutes),txt(b.notes)||null]);
    });
    res.json({ok:true});
  }));
}
