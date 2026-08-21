import { withTransaction } from './db.js';
import { requireRole } from './auth.js';
import { ensureFifoLayers } from './fifo_costing_v8.js';

const wrapNext=fn=>async(req,res,next)=>{
  try{await fn(req,res);next();}
  catch(error){
    console.error('fifo receipt v8 error',error);
    res.status(error.status||400).json({error:error.message,details:error.details||undefined});
  }
};

export function registerFifoReceiptV8Guard(app){
  // Runs before the accounting goods-receipt POST handler. FIFO layers represent
  // physically accepted stock and therefore must exist before the first issue,
  // landed-cost allocation or inventory valuation report. ensureFifoLayers uses
  // INSERT IGNORE over the unique goods_receipt_line_id, so retries are safe.
  app.post('/api/iran/goods-receipts/:id/post',requireRole('ACCOUNTANT','FINANCE_MANAGER'),wrapNext(async(req)=>{
    const receiptId=Number(req.params.id);
    if(!Number.isFinite(receiptId)||receiptId<=0)return;
    await withTransaction(async conn=>{
      const [grs]=await conn.execute(
        'SELECT id,company_id,warehouse_id FROM goods_receipts WHERE id=? AND company_id=? FOR UPDATE',
        [receiptId,req.user.companyId]
      );
      if(!grs.length)return;
      const [[policy]]=await conn.execute(
        'SELECT inventory_valuation FROM company_accounting_policies WHERE company_id=?',
        [req.user.companyId]
      );
      if(policy?.inventory_valuation!=='FIFO')return;
      const [lines]=await conn.execute(
        'SELECT DISTINCT product_id FROM goods_receipt_lines WHERE goods_receipt_id=? AND accepted_qty>0',
        [receiptId]
      );
      for(const line of lines){
        await ensureFifoLayers(conn,req.user.companyId,grs[0].warehouse_id,line.product_id);
      }
    });
  }));
}
