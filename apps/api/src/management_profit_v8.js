import { pool } from './db.js';
import { requireRole } from './auth.js';
const n=v=>Number(v||0);
const wrap=fn=>async(req,res)=>{try{await fn(req,res)}catch(e){console.error('profit dashboard v8 error',e);res.status(e.status||400).json({error:e.message})}};
export function registerManagementProfitV8(app){
 app.get('/api/iran/v8/reports/item-profitability-dashboard',requireRole('FINANCE_MANAGER','ACCOUNTANT','SALES_MANAGER'),wrap(async(req,res)=>{
   const c=req.user.companyId,from=req.query.from||'1900-01-01',to=req.query.to||'2999-12-31';
   const [rows]=await pool.execute(`SELECT p.id product_id,p.sku,p.name,p.unit,
    COALESCE((SELECT SUM(l.qty) FROM purchase_invoice_lines l JOIN purchase_invoices h ON h.id=l.invoice_id WHERE l.product_id=p.id AND h.company_id=p.company_id AND h.invoice_date BETWEEN ? AND ? AND h.status<>'VOID'),0) purchase_qty,
    COALESCE((SELECT SUM(l.line_total) FROM purchase_invoice_lines l JOIN purchase_invoices h ON h.id=l.invoice_id WHERE l.product_id=p.id AND h.company_id=p.company_id AND h.invoice_date BETWEEN ? AND ? AND h.status<>'VOID'),0) purchase_amount,
    COALESCE((SELECT SUM(l.qty) FROM sales_invoice_lines l JOIN sales_invoices h ON h.id=l.invoice_id WHERE l.product_id=p.id AND h.company_id=p.company_id AND h.invoice_date BETWEEN ? AND ? AND h.is_void=0),0) sales_qty,
    COALESCE((SELECT SUM(l.line_total) FROM sales_invoice_lines l JOIN sales_invoices h ON h.id=l.invoice_id WHERE l.product_id=p.id AND h.company_id=p.company_id AND h.invoice_date BETWEEN ? AND ? AND h.is_void=0),0) sales_amount,
    COALESCE((SELECT SUM(COALESCE(l.cogs_amount,0)) FROM sales_invoice_lines l JOIN sales_invoices h ON h.id=l.invoice_id WHERE l.product_id=p.id AND h.company_id=p.company_id AND h.invoice_date BETWEEN ? AND ? AND h.is_void=0),0) cogs_amount
    FROM products p WHERE p.company_id=? AND p.is_deleted=0 ORDER BY p.name`,[from,to,from,to,from,to,from,to,from,to,c]);
   const items=rows.map(x=>{const pq=n(x.purchase_qty),pa=n(x.purchase_amount),sq=n(x.sales_qty),sa=n(x.sales_amount),cogs=n(x.cogs_amount),gp=sa-cogs,margin=sa?gp/sa*100:0,variance=pq-sq;return{...x,purchase_avg:pq?pa/pq:0,sales_avg:sq?sa/sq:0,gross_profit:gp,gross_margin_pct:margin,qty_variance:variance,status:variance<-.0001?'OVER_SOLD':Math.abs(variance)<.0001?'SETTLED':'STOCK_REMAINS'}});
   const active=items.filter(x=>n(x.purchase_amount)||n(x.sales_amount));
   const totals=active.reduce((a,x)=>({purchase_amount:a.purchase_amount+n(x.purchase_amount),sales_amount:a.sales_amount+n(x.sales_amount),cogs_amount:a.cogs_amount+n(x.cogs_amount),gross_profit:a.gross_profit+n(x.gross_profit)}),{purchase_amount:0,sales_amount:0,cogs_amount:0,gross_profit:0});
   totals.gross_margin_pct=totals.sales_amount?totals.gross_profit/totals.sales_amount*100:0;
   const topProfit=[...active].sort((a,b)=>n(b.gross_profit)-n(a.gross_profit))[0]||null;
   const topMargin=[...active].filter(x=>n(x.sales_amount)>0).sort((a,b)=>n(b.gross_margin_pct)-n(a.gross_margin_pct))[0]||null;
   const overSold=active.filter(x=>x.status==='OVER_SOLD');
   const stockRemains=active.filter(x=>x.status==='STOCK_REMAINS');
   const conclusions=[];
   if(topProfit)conclusions.push(`بیشترین سود ناخالص ریالی مربوط به «${topProfit.name}» با مبلغ ${Math.round(n(topProfit.gross_profit))} ریال است.`);
   if(topMargin)conclusions.push(`بالاترین حاشیه سود مربوط به «${topMargin.name}» با حدود ${n(topMargin.gross_margin_pct).toFixed(2)} درصد است.`);
   if(overSold.length)conclusions.push(`${overSold.length} قلم در وضعیت اضافه‌فروش قرار دارند و باید موجودی/حواله/مبنای خرید آن‌ها کنترل شود.`);
   if(stockRemains.length)conclusions.push(`${stockRemains.length} قلم هنوز مانده خرید نسبت به فروش دارند.`);
   res.json({period:{from,to},totals:{...totals,item_count:active.length},top_profit:topProfit,top_margin:topMargin,over_sold:overSold,stock_remains:stockRemains,conclusions,items:active});
 }));
}
