import { pool } from './db.js';
import { requireRole } from './auth.js';

const txt=v=>String(v??'').trim();
const num=v=>Number(v||0);
const fail=(message,status=400,details=null)=>{const e=new Error(message);e.status=status;e.details=details;throw e};
const wrap=fn=>async(req,res)=>{try{await fn(req,res)}catch(e){console.error('bank master v8',e);res.status(e.status||400).json({error:e.message,details:e.details||undefined})}};
const read=requireRole('SUPER_ADMIN','FINANCE_MANAGER','ACCOUNTANT','TREASURY_MANAGER');
const write=requireRole('SUPER_ADMIN','FINANCE_MANAGER','TREASURY_MANAGER');

function normalizeIban(v){return txt(v).toUpperCase().replace(/[\s-]/g,'')||null}
function digits(v){return txt(v).replace(/\D/g,'')||null}
function validate(b){
  if(!txt(b.code)||!txt(b.bankName)||!txt(b.accountTitle))fail('کد حساب، نام بانک و عنوان حساب الزامی است.');
  const iban=normalizeIban(b.iban);if(iban&&!/^IR\d{24}$/.test(iban))fail('شماره شبا باید با IR شروع شده و شامل ۲۴ رقم باشد.');
  const card=digits(b.cardNo);if(card&&card.length!==16)fail('شماره کارت باید ۱۶ رقمی باشد.');
  return{iban,card};
}
async function audit(req,action,id,before,after){try{await pool.execute(`INSERT INTO audit_logs(company_id,user_id,action,entity_type,entity_id,before_json,after_json,ip_address,user_agent) VALUES (?,?,?,?,?,?,?,?,?)`,[req.user.companyId,Number(req.user.sub),action,'BANK_ACCOUNT',String(id),before?JSON.stringify(before):null,after?JSON.stringify(after):null,req.ip,req.headers['user-agent']||null])}catch(e){console.warn('bank audit',e.message)}}

export function registerBankMasterV8Routes(app){
  app.get('/api/iran/treasury/bank-accounts',read,wrap(async(req,res)=>{
    const q=txt(req.query.q),active=txt(req.query.active),where=['b.company_id=?'],p=[req.user.companyId];
    if(q){const like=`%${q}%`;where.push('(b.code LIKE ? OR b.bank_name LIKE ? OR b.account_title LIKE ? OR b.account_no LIKE ? OR b.iban LIKE ? OR b.card_no LIKE ? OR b.branch_name LIKE ?)');p.push(like,like,like,like,like,like,like)}
    if(active!=='') {where.push('b.is_active=?');p.push(active==='1'||active==='true'?1:0)}
    const [rows]=await pool.execute(`SELECT b.*,a.code gl_account_code,a.title gl_account_title,br.name branch_title FROM bank_accounts b LEFT JOIN accounts a ON a.id=b.gl_account_id LEFT JOIN branches br ON br.id=b.branch_id WHERE ${where.join(' AND ')} ORDER BY b.is_default DESC,b.is_active DESC,b.bank_name,b.code`,p);
    res.json(rows.map(x=>({...x,card_cvv2:x.card_cvv2?String(x.card_cvv2):null})));
  }));

  app.post('/api/iran/treasury/bank-accounts',write,wrap(async(req,res)=>{
    const b=req.body||{},v=validate(b),c=req.user.companyId;
    if(b.isDefault)await pool.execute('UPDATE bank_accounts SET is_default=0 WHERE company_id=?',[c]);
    const [r]=await pool.execute(`INSERT INTO bank_accounts(company_id,branch_id,code,bank_name,branch_name,branch_code,account_type,account_title,account_holder,account_no,iban,card_no,card_expiry,card_cvv2,bank_phone,bank_fax,bank_address,description,currency,opening_balance,gl_account_id,show_on_sales_invoice,show_on_receipt,is_default,is_active) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,[c,b.branchId||null,txt(b.code),txt(b.bankName),txt(b.branchName)||null,txt(b.branchCode)||null,txt(b.accountType)||null,txt(b.accountTitle),txt(b.accountHolder)||null,txt(b.accountNo)||null,v.iban,v.card,txt(b.cardExpiry)||null,txt(b.cardCvv2)||null,txt(b.bankPhone)||null,txt(b.bankFax)||null,txt(b.bankAddress)||null,txt(b.description)||null,txt(b.currency)||'IRR',num(b.openingBalance),b.glAccountId||null,b.showOnSalesInvoice?1:0,b.showOnReceipt?1:0,b.isDefault?1:0,b.isActive===false?0:1]);
    const [[created]]=await pool.execute('SELECT * FROM bank_accounts WHERE id=? AND company_id=?',[r.insertId,c]);await audit(req,'CREATE',r.insertId,null,created);res.status(201).json(created);
  }));

  app.put('/api/iran/treasury/bank-accounts/:id',write,wrap(async(req,res)=>{
    const id=Number(req.params.id),b=req.body||{},c=req.user.companyId;const [oldRows]=await pool.execute('SELECT * FROM bank_accounts WHERE id=? AND company_id=?',[id,c]);if(!oldRows.length)fail('حساب بانکی پیدا نشد.',404);const old=oldRows[0];const merged={code:b.code??old.code,bankName:b.bankName??old.bank_name,accountTitle:b.accountTitle??old.account_title,iban:b.iban??old.iban,cardNo:b.cardNo??old.card_no},v=validate(merged);
    if(b.isDefault===true)await pool.execute('UPDATE bank_accounts SET is_default=0 WHERE company_id=? AND id<>?',[c,id]);
    await pool.execute(`UPDATE bank_accounts SET branch_id=?,code=?,bank_name=?,branch_name=?,branch_code=?,account_type=?,account_title=?,account_holder=?,account_no=?,iban=?,card_no=?,card_expiry=?,card_cvv2=?,bank_phone=?,bank_fax=?,bank_address=?,description=?,currency=?,opening_balance=?,gl_account_id=?,show_on_sales_invoice=?,show_on_receipt=?,is_default=?,is_active=? WHERE id=? AND company_id=?`,[b.branchId===undefined?old.branch_id:(b.branchId||null),txt(b.code??old.code),txt(b.bankName??old.bank_name),b.branchName===undefined?old.branch_name:(txt(b.branchName)||null),b.branchCode===undefined?old.branch_code:(txt(b.branchCode)||null),b.accountType===undefined?old.account_type:(txt(b.accountType)||null),txt(b.accountTitle??old.account_title),b.accountHolder===undefined?old.account_holder:(txt(b.accountHolder)||null),b.accountNo===undefined?old.account_no:(txt(b.accountNo)||null),v.iban,v.card,b.cardExpiry===undefined?old.card_expiry:(txt(b.cardExpiry)||null),b.cardCvv2===undefined?old.card_cvv2:(txt(b.cardCvv2)||null),b.bankPhone===undefined?old.bank_phone:(txt(b.bankPhone)||null),b.bankFax===undefined?old.bank_fax:(txt(b.bankFax)||null),b.bankAddress===undefined?old.bank_address:(txt(b.bankAddress)||null),b.description===undefined?old.description:(txt(b.description)||null),txt(b.currency??old.currency)||'IRR',b.openingBalance===undefined?old.opening_balance:num(b.openingBalance),b.glAccountId===undefined?old.gl_account_id:(b.glAccountId||null),b.showOnSalesInvoice===undefined?old.show_on_sales_invoice:(b.showOnSalesInvoice?1:0),b.showOnReceipt===undefined?old.show_on_receipt:(b.showOnReceipt?1:0),b.isDefault===undefined?old.is_default:(b.isDefault?1:0),b.isActive===undefined?old.is_active:(b.isActive?1:0),id,c]);
    const [[after]]=await pool.execute('SELECT * FROM bank_accounts WHERE id=? AND company_id=?',[id,c]);await audit(req,'UPDATE',id,old,after);res.json(after);
  }));

  app.post('/api/iran/treasury/bank-accounts/:id/set-default',write,wrap(async(req,res)=>{
    const id=Number(req.params.id),c=req.user.companyId;const [r]=await pool.execute('SELECT id FROM bank_accounts WHERE id=? AND company_id=? AND is_active=1',[id,c]);if(!r.length)fail('حساب بانکی فعال پیدا نشد.',404);await pool.execute('UPDATE bank_accounts SET is_default=(id=?) WHERE company_id=?',[id,c]);await audit(req,'SET_DEFAULT',id,null,{isDefault:true});res.json({ok:true,id});
  }));
}
