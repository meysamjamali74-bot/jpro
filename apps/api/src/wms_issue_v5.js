import { withTransaction } from './db.js';
import { requireRole } from './auth.js';
import { issueAllocations } from './inventory_allocation_v5.js';
import { consumeFifo } from './fifo_costing_v8.js';

const n=v=>Number(v||0);
const fail=(m,s=400,d=null)=>{const e=new Error(m);e.status=s;e.details=d;throw e};
const wrap=fn=>async(req,res)=>{try{await fn(req,res)}catch(e){console.error('wms issue v5 error',e);res.status(e.status||400).json({error:e.message,details:e.details||undefined})}};

async function acc(conn,c,code){
  const [r]=await conn.execute('SELECT id FROM accounts WHERE company_id=? AND code=?',[c,code]);
  if(!r.length)fail(`حساب ${code} تعریف نشده است.`,422);
  return r[0].id;
}

async function nextNo(conn,c){
  const lock=`trz:wmsadj:${c}`;
  const [[g]]=await conn.query('SELECT GET_LOCK(?,5) got',[lock]);
  if(!g?.got)fail('شماره‌گذاری سند درگیر است.',409);
  try{
    let [r]=await conn.execute(`SELECT id,last_number,prefix,pad_length FROM document_sequences WHERE company_id=? AND branch_id IS NULL AND fiscal_year_id IS NULL AND document_type='JOURNAL_IR' ORDER BY id LIMIT 1 FOR UPDATE`,[c]);
    if(!r.length){
      await conn.execute(`INSERT INTO document_sequences(company_id,document_type,prefix,last_number,pad_length) VALUES (?,'JOURNAL_IR','JE',0,6)`,[c]);
      [r]=await conn.execute(`SELECT id,last_number,prefix,pad_length FROM document_sequences WHERE company_id=? AND branch_id IS NULL AND fiscal_year_id IS NULL AND document_type='JOURNAL_IR' ORDER BY id LIMIT 1 FOR UPDATE`,[c]);
    }
    const x=r[0],v=n(x.last_number)+1;
    await conn.execute('UPDATE document_sequences SET last_number=? WHERE id=?',[v,x.id]);
    return`${x.prefix||'JE'}-${String(v).padStart(Number(x.pad_length||6),'0')}`;
  }finally{
    await conn.query('SELECT RELEASE_LOCK(?)',[lock]);
  }
}

async function adjustment(conn,c,date,sourceId,delta,user){
  if(Math.abs(delta)<.5)return null;
  const cogs=await acc(conn,c,'510100'),inv=await acc(conn,c,'130100'),no=await nextNo(conn,c);
  const [j]=await conn.execute(`INSERT INTO journal_entries(company_id,entry_no,entry_date,posting_date,status,source_type,source_id,description,created_by,posted_at) VALUES (?,?,?,?, 'POSTED','COGS_VALUATION_ADJUSTMENT',?,'تعدیل بهای تمام‌شده خروج انبار',?,NOW())`,[c,no,date,date,sourceId,user]);
  if(delta>0){
    await conn.execute(`INSERT INTO journal_lines(journal_entry_id,account_id,debit,credit,description) VALUES (?,?,?,0,'تعدیل بهای تمام‌شده'),(?,?,0,?,'تعدیل موجودی')`,[j.insertId,cogs,delta,j.insertId,inv,delta]);
  }else{
    const a=-delta;
    await conn.execute(`INSERT INTO journal_lines(journal_entry_id,account_id,debit,credit,description) VALUES (?,?,?,0,'تعدیل موجودی'),(?,?,0,?,'تعدیل بهای تمام‌شده')`,[j.insertId,inv,a,j.insertId,cogs,a]);
  }
  return j.insertId;
}

export function registerWmsIssueV5Routes(app){
  app.post('/api/iran/sales/fulfillments/:id/issue',requireRole('WAREHOUSE_MANAGER'),wrap(async(req,res)=>{
    const id=Number(req.params.id);
    const result=await withTransaction(async conn=>{
      const [fs]=await conn.execute('SELECT * FROM sales_fulfillments WHERE id=? AND company_id=? FOR UPDATE',[id,req.user.companyId]);
      if(!fs.length||!['PACKED','PICKED','RESERVED'].includes(fs[0].status))fail('فرآیند قابل خروج نیست.',422);
      const f=fs[0];
      const [pr]=await conn.execute('SELECT * FROM company_accounting_policies WHERE company_id=?',[req.user.companyId]);
      if(!pr.length)fail('سیاست حسابداری/انبار تعریف نشده است.',422);
      const policy=pr[0];
      const [lines]=await conn.execute(`SELECT fl.*,sil.cogs_amount old_cogs FROM sales_fulfillment_lines fl JOIN sales_invoice_lines sil ON sil.id=fl.sales_invoice_line_id WHERE fl.fulfillment_id=? FOR UPDATE`,[id]);
      let total=0,old=0;

      for(const l of lines){
        const allocations=await issueAllocations(conn,f,l);
        if(!allocations.length)fail('تخصیص موجودی برای خروج پیدا نشد.',422,{productId:l.product_id});
        let lineQty=0,lineCost=0;

        for(const a of allocations){
          const qty=n(a.issue_qty);
          if(qty<=.00005)continue;
          if(n(a.on_hand_qty)+.00005<qty){
            if(!policy.allow_negative_inventory||policy.inventory_valuation==='FIFO'){
              fail('موجودی تخصیص‌یافته برای خروج کافی نیست.',422,{productId:l.product_id,batchNo:a.batch_no,expiryDate:a.expiry_date,onHand:n(a.on_hand_qty),qty});
            }
          }

          const release=Math.min(qty,n(a.balance_reserved??a.reserved_qty));
          await conn.execute(`UPDATE inventory_balances SET on_hand_qty=on_hand_qty-?,reserved_qty=GREATEST(0,reserved_qty-?) WHERE id=?`,[qty,release,a.inventory_balance_id]);

          const provisional=qty*n(a.average_cost);
          const [mv]=await conn.execute(`INSERT INTO inventory_movements(company_id,warehouse_id,product_id,movement_date,movement_type,quantity,unit_cost,batch_no,expiry_date,source_type,source_id,created_by) VALUES (?,?,?,NOW(),'ISSUE',?,?,?,?, 'SALES_FULFILLMENT',?,?)`,[req.user.companyId,f.warehouse_id,l.product_id,-qty,n(a.average_cost),a.batch_no||null,a.expiry_date?String(a.expiry_date).slice(0,10):null,id,Number(req.user.sub)]);

          let cost=provisional;
          if(policy.inventory_valuation==='FIFO'){
            const fifo=await consumeFifo(conn,{
              companyId:req.user.companyId,
              warehouseId:f.warehouse_id,
              productId:l.product_id,
              quantity:qty,
              movementId:mv.insertId,
              sourceType:'SALES_FULFILLMENT',
              sourceId:id
            });
            cost=n(fifo.cost);
          }else if(policy.inventory_valuation==='PERIODIC_WEIGHTED_AVERAGE'){
            await conn.execute(`INSERT INTO control_exceptions(company_id,exception_code,severity,entity_type,entity_id,title,details_json) VALUES (?,'PERIODIC_COGS_PROVISIONAL','INFO','SALES_FULFILLMENT',?,'بهای تمام‌شده موقت تا محاسبه میانگین دوره‌ای',?)`,[req.user.companyId,id,JSON.stringify({productId:l.product_id,batchNo:a.batch_no,provisionalCost:cost})]);
          }

          if(a.allocation_id){
            await conn.execute(`UPDATE sales_fulfillment_allocations SET issued_qty=?,status='ISSUED',issued_at=NOW() WHERE id=?`,[qty,a.allocation_id]);
          }
          lineQty+=qty;
          lineCost+=cost;
        }

        const unit=lineQty?lineCost/lineQty:0;
        await conn.execute(`UPDATE sales_fulfillment_lines SET issued_qty=?,actual_unit_cost=?,actual_cost_amount=? WHERE id=?`,[lineQty,unit,lineCost,l.id]);
        await conn.execute(`UPDATE sales_invoice_lines SET unit_cost_snapshot=?,cogs_amount=?,gross_profit_amount=amount_after_discount-? WHERE id=?`,[unit,lineCost,lineCost,l.sales_invoice_line_id]);
        total+=lineCost;
        old+=n(l.old_cogs);
      }

      await conn.execute(`UPDATE sales_fulfillments SET status='ISSUED',issued_at=NOW() WHERE id=?`,[id]);
      await conn.execute(`UPDATE sales_invoices SET fulfillment_status='ISSUED',inventory_issue_posted=1,inventory_issue_at=NOW(),warehouse_id=COALESCE(warehouse_id,?) WHERE id=?`,[f.warehouse_id,f.sales_invoice_id]);
      const [iv]=await conn.execute('SELECT posted_at,invoice_date FROM sales_invoices WHERE id=?',[f.sales_invoice_id]);
      let adj=null;
      if(iv[0]?.posted_at)adj=await adjustment(conn,req.user.companyId,iv[0].invoice_date,id,total-old,Number(req.user.sub));
      return{ok:true,status:'ISSUED',valuationMethod:policy.inventory_valuation,pickingStrategy:policy.default_picking_strategy,actualCost:total,oldCost:old,adjustment:total-old,adjustmentJournalId:adj};
    });
    res.json(result);
  }));
}
