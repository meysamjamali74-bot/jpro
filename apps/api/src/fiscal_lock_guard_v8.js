import { pool } from './db.js';

const MUTATING=new Set(['POST','PUT','PATCH','DELETE']);
const DATE_KEYS=['postingDate','entryDate','invoiceDate','noteDate','receiptDate','paymentDate','transactionDate','settlementDate','issueDate','returnDate','revaluationDate','documentDate','date'];

function normalizeDate(v){
  if(v==null||v==='')return null;
  const s=String(v).trim().slice(0,10);
  return /^\d{4}-\d{2}-\d{2}$/.test(s)?s:null;
}
function bodyDate(body={}){
  for(const k of DATE_KEYS){const d=normalizeDate(body?.[k]);if(d)return d}
  return null;
}
function pathId(path,re){const m=String(path||'').match(re);return m?Number(m[1]):null}

async function journalDateById(companyId,id){
  if(!id)return null;
  const [r]=await pool.execute(`SELECT DATE(COALESCE(posting_date,entry_date)) d FROM journal_entries WHERE id=? AND company_id=? LIMIT 1`,[id,companyId]);
  return r.length?normalizeDate(r[0].d):null;
}
async function journalDateByLineId(companyId,id){
  if(!id)return null;
  const [r]=await pool.execute(`SELECT DATE(COALESCE(je.posting_date,je.entry_date)) d FROM journal_lines jl JOIN journal_entries je ON je.id=jl.journal_entry_id WHERE jl.id=? AND je.company_id=? LIMIT 1`,[id,companyId]);
  return r.length?normalizeDate(r[0].d):null;
}

const ENTITY_ROUTES=[
  {re:/\/sales-invoices\/(\d+)(?:\/|$)/i,table:'sales_invoices',date:'invoice_date'},
  {re:/\/purchase-invoices\/(\d+)(?:\/|$)/i,table:'purchase_invoices',date:'invoice_date'},
  {re:/\/ar-credit-notes\/(\d+)(?:\/|$)/i,table:'ar_credit_notes',date:'note_date'},
  {re:/\/ap-debit-notes\/(\d+)(?:\/|$)/i,table:'ap_debit_notes',date:'note_date'},
  {re:/\/receipts\/(\d+)(?:\/|$)/i,table:'receipts',date:'posting_date',fallback:'receipt_date'},
  {re:/\/payments\/(\d+)(?:\/|$)/i,table:'payments',date:'posting_date',fallback:'payment_date'}
];
async function sourceDate(companyId,path){
  for(const x of ENTITY_ROUTES){
    const id=pathId(path,x.re);if(!id)continue;
    const expr=x.fallback?`COALESCE(${x.date},${x.fallback})`:x.date;
    const [r]=await pool.query(`SELECT DATE(${expr}) d FROM ${x.table} WHERE id=? AND company_id=? LIMIT 1`,[id,companyId]);
    if(r.length)return normalizeDate(r[0].d);
  }
  return null;
}
async function hardClosed(companyId,date){
  if(!date)return null;
  const [r]=await pool.execute(`SELECT id,start_date,end_date FROM fiscal_periods WHERE company_id=? AND status='HARD_CLOSED' AND ? BETWEEN start_date AND end_date ORDER BY start_date DESC LIMIT 1`,[companyId,date]);
  return r[0]||null;
}

export async function fiscalLockGuardV8(req,res,next){
  try{
    if(!MUTATING.has(String(req.method||'').toUpperCase())||!req.user?.companyId)return next();
    const companyId=Number(req.user.companyId),path=String(req.path||req.originalUrl||'');
    let date=bodyDate(req.body);

    const journalId=pathId(path,/\/(?:journal-entries|journals|journal)\/(\d+)(?:\/|$)/i);
    if(!date&&journalId)date=await journalDateById(companyId,journalId);

    const journalLineId=pathId(path,/\/journal-lines\/(\d+)(?:\/|$)/i);
    if(!date&&journalLineId)date=await journalDateByLineId(companyId,journalLineId);

    const bodyJournalId=Number(req.body?.journalEntryId||req.body?.journal_entry_id||0);
    if(!date&&bodyJournalId)date=await journalDateById(companyId,bodyJournalId);

    if(!date)date=await sourceDate(companyId,path);
    if(!date)return next();

    const period=await hardClosed(companyId,date);
    if(!period)return next();

    return res.status(423).json({
      error:'دوره مالی این تاریخ به‌صورت قطعی بسته شده است و هیچ ثبت، ویرایش یا حذف مالی مجاز نیست.',
      code:'ACCOUNTING_PERIOD_HARD_CLOSED',
      date,
      periodId:period.id
    });
  }catch(error){
    console.error('fiscal lock guard',error);
    return res.status(500).json({error:'کنترل قفل دوره مالی با خطا مواجه شد.',code:'FISCAL_LOCK_GUARD_ERROR'});
  }
}
