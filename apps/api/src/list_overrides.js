import { pool } from './db.js';
import { requireRole } from './auth.js';
const text=v=>String(v??'').trim(),n=v=>Number(v||0);
const wrap=fn=>async(req,res)=>{try{await fn(req,res)}catch(e){console.error('list override error',e);res.status(400).json({error:e.message})}};
export function registerListOverrides(app){
 app.get('/api/iran/purchase-invoices',requireRole('ACCOUNTANT','FINANCE_MANAGER','WAREHOUSE_MANAGER'),wrap(async(req,res)=>{
   const q=text(req.query.q),status=text(req.query.status),classification=text(req.query.classification),dateFrom=text(req.query.dateFrom),dateTo=text(req.query.dateTo);
   const page=Math.max(1,n(req.query.page)||1),pageSize=Math.min(200,Math.max(10,n(req.query.pageSize)||50)),offset=(page-1)*pageSize;
   const where=['pi.company_id=?','pi.is_void=0'],params=[req.user.companyId];
   if(q){const like=`%${q}%`;where.push('(pi.invoice_no LIKE ? OR pi.supplier_invoice_no LIKE ? OR p.name LIKE ? OR pi.tax_unique_no LIKE ?)');params.push(like,like,like,like)}
   if(status){where.push('pi.status=?');params.push(status)}
   if(classification){where.push('pi.invoice_classification=?');params.push(classification)}
   if(dateFrom){where.push('pi.invoice_date>=?');params.push(dateFrom)}
   if(dateTo){where.push('pi.invoice_date<=?');params.push(dateTo)}
   const w=where.join(' AND ');
   const [[count]]=await pool.execute(`SELECT COUNT(*) total FROM purchase_invoices pi JOIN parties p ON p.id=pi.supplier_party_id WHERE ${w}`,params);
   const [rows]=await pool.execute(`SELECT pi.*,p.name supplier,po.po_no,gr.receipt_no,(SELECT COUNT(*) FROM purchase_match_results mr WHERE mr.purchase_invoice_id=pi.id AND mr.status='OPEN') open_match_count FROM purchase_invoices pi JOIN parties p ON p.id=pi.supplier_party_id LEFT JOIN purchase_orders po ON po.id=pi.purchase_order_id LEFT JOIN goods_receipts gr ON gr.id=pi.goods_receipt_id WHERE ${w} ORDER BY pi.invoice_date DESC,pi.id DESC LIMIT ${pageSize} OFFSET ${offset}`,params);
   res.json({rows,total:n(count.total),page,pageSize});
 }));
}