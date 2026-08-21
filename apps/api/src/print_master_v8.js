import { pool } from './db.js';
import { requireRole } from './auth.js';

const fail=(m,s=400)=>{const e=new Error(m);e.status=s;throw e};
const wrap=fn=>async(req,res)=>{try{await fn(req,res)}catch(e){console.error('print master v8',e);res.status(e.status||400).json({error:e.message})}};
const read=requireRole('SUPER_ADMIN','FINANCE_MANAGER','ACCOUNTANT','SALES_MANAGER','SALES_PERSON','WAREHOUSE_MANAGER','LOGISTICS_MANAGER','PURCHASE_MANAGER');

async function companyModel(companyId){
  const [[company]]=await pool.execute(`SELECT c.*,tp.taxpayer_memory_id,tp.tax_terminal_id,tp.default_invoice_type,tp.default_invoice_pattern,tp.taxpayer_system_enabled FROM companies c LEFT JOIN company_tax_profiles tp ON tp.company_id=c.id WHERE c.id=?`,[companyId]);
  const [banks]=await pool.execute(`SELECT id,code,bank_name,branch_name,branch_code,account_type,account_title,account_holder,account_no,iban,card_no,card_expiry,currency,is_default FROM bank_accounts WHERE company_id=? AND is_active=1 AND show_on_sales_invoice=1 ORDER BY is_default DESC,bank_name,code`,[companyId]);
  return{company,banks};
}
async function defaultProfile(companyId,type){
  const [r]=await pool.execute(`SELECT * FROM print_profiles WHERE company_id=? AND document_type=? AND is_active=1 ORDER BY is_default DESC,id DESC LIMIT 1`,[companyId,type]);
  return r[0]||null;
}

export function registerPrintMasterV8Routes(app){
  app.get('/api/iran/print/sales-invoices/:id',read,wrap(async(req,res)=>{
    const id=Number(req.params.id),c=req.user.companyId;
    const [[h]]=await pool.execute(`SELECT si.*,p.code customer_code,p.name customer_name,p.party_type customer_type,p.national_id customer_national_id,p.economic_code customer_economic_code,p.registration_no customer_registration_no,p.postal_code customer_postal_code,p.province customer_province,p.city customer_city,p.address customer_address,p.mobile customer_mobile,p.phone customer_phone,u.full_name salesperson_name FROM sales_invoices si JOIN parties p ON p.id=si.customer_party_id LEFT JOIN users u ON u.id=si.salesperson_user_id WHERE si.id=? AND si.company_id=?`,[id,c]);
    if(!h)fail('فاکتور فروش پیدا نشد.',404);
    const [lines]=await pool.execute(`SELECT l.id,l.product_id,p.sku,p.barcode,p.name product_name,p.brand,p.unit,l.description,l.goods_service_id,l.unit_code,l.qty,l.unit_price,l.discount_amount,l.amount_before_discount,l.amount_after_discount,l.vat_status,l.vat_rate,l.tax_amount,l.other_duties_amount,l.other_duties_description,l.line_total FROM sales_invoice_lines l JOIN products p ON p.id=l.product_id WHERE l.invoice_id=? ORDER BY l.id`,[id]);
    const [addresses]=await pool.execute(`SELECT address_type,title,province,city,postal_code,address_text,is_primary FROM party_addresses WHERE party_id=? AND is_active=1 ORDER BY is_primary DESC,id`,[h.customer_party_id]);
    const {company,banks}=await companyModel(c),profile=await defaultProfile(c,'SALES_INVOICE');
    const totals={gross:Number(h.gross_total||0),discount:Number(h.discount_total||0),tax:Number(h.tax_total||0),net:Number(h.net_total||0),outstanding:Number(h.outstanding_amount||0),paid:Math.max(0,Number(h.net_total||0)-Number(h.outstanding_amount||0))};
    res.json({documentType:'SALES_INVOICE',classification:h.invoice_classification,taxInvoiceType:h.tax_invoice_type,company,customer:{id:h.customer_party_id,code:h.customer_code,name:h.customer_name,type:h.customer_type,nationalId:h.customer_national_id,economicCode:h.customer_economic_code,registrationNo:h.customer_registration_no,postalCode:h.customer_postal_code,province:h.customer_province,city:h.customer_city,address:h.customer_address,mobile:h.customer_mobile,phone:h.customer_phone,addresses},invoice:h,lines,totals,banks,printProfile:profile,security:{cvvStored:false}});
  }));

  app.get('/api/iran/print/waybills/:id',read,wrap(async(req,res)=>{
    const id=Number(req.params.id),c=req.user.companyId;
    const [[w]]=await pool.execute(`SELECT w.*,si.invoice_no,si.invoice_date,sp.name sender_name,sp.mobile sender_mobile,sp.phone sender_phone,rp.name receiver_party_name,rp.mobile receiver_mobile,rp.phone receiver_phone,t.trip_no,v.plate_no FROM logistics_waybills w LEFT JOIN sales_invoices si ON si.id=w.sales_invoice_id LEFT JOIN parties sp ON sp.id=w.sender_party_id LEFT JOIN parties rp ON rp.id=w.receiver_party_id LEFT JOIN trips t ON t.id=w.trip_id LEFT JOIN vehicles v ON v.id=t.vehicle_id WHERE w.id=? AND w.company_id=?`,[id,c]);
    if(!w)fail('بارنامه پیدا نشد.',404);
    let lines=[];if(w.sales_invoice_id){[lines]=await pool.execute(`SELECT p.sku,p.name product_name,p.unit,l.qty,l.unit_price,l.line_total FROM sales_invoice_lines l JOIN products p ON p.id=l.product_id WHERE l.invoice_id=? ORDER BY l.id`,[w.sales_invoice_id])}
    let senderAddresses=[],receiverAddresses=[];
    if(w.sender_party_id)[senderAddresses]=await pool.execute(`SELECT address_type,title,province,city,postal_code,address_text,is_primary FROM party_addresses WHERE party_id=? AND is_active=1 ORDER BY is_primary DESC,id`,[w.sender_party_id]);
    if(w.receiver_party_id)[receiverAddresses]=await pool.execute(`SELECT address_type,title,province,city,postal_code,address_text,is_primary FROM party_addresses WHERE party_id=? AND is_active=1 ORDER BY is_primary DESC,id`,[w.receiver_party_id]);
    const {company}=await companyModel(c),profile=await defaultProfile(c,'WAYBILL');
    res.json({documentType:'WAYBILL',company,waybill:w,parties:{sender:{name:w.sender_name,mobile:w.sender_mobile,phone:w.sender_phone,addresses:senderAddresses},receiver:{name:w.receiver_party_name||w.receiver_name,mobile:w.receiver_mobile||w.receiver_phone,phone:w.receiver_phone,addresses:receiverAddresses}},lines,charges:{freight:Number(w.freight_amount||0),insurance:Number(w.insurance_amount||0),other:Number(w.other_charges||0),total:Number(w.freight_amount||0)+Number(w.insurance_amount||0)+Number(w.other_charges||0)},printProfile:profile});
  }));

  app.get('/api/iran/print/price-lists/:id',read,wrap(async(req,res)=>{
    const id=Number(req.params.id),c=req.user.companyId;const [[h]]=await pool.execute('SELECT * FROM price_lists WHERE id=? AND company_id=?',[id,c]);if(!h)fail('لیست قیمت پیدا نشد.',404);
    const [items]=await pool.execute(`SELECT i.*,p.sku,p.name product_name,p.brand,p.unit,p.barcode,(SELECT media_url FROM product_media pm WHERE pm.product_id=p.id AND pm.media_type='IMAGE' ORDER BY pm.is_primary DESC,pm.sort_order,pm.id LIMIT 1) image_url FROM price_list_items i JOIN products p ON p.id=i.product_id WHERE i.price_list_id=? AND i.is_active=1 ORDER BY p.category,p.brand,p.name`,[id]);
    const {company}=await companyModel(c),profile=await defaultProfile(c,'PRICE_LIST');res.json({documentType:'PRICE_LIST',company,priceList:h,items,printProfile:profile});
  }));
}
