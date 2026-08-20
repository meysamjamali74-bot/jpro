import { pool } from './db.js';
import { requireRole } from './auth.js';
const n=v=>Number(v||0),txt=v=>String(v??'').trim();
const wrap=fn=>async(req,res)=>{try{await fn(req,res)}catch(e){console.error('bank v8 compat error',e);res.status(e.status||400).json({error:e.message})}};
export function registerMasterDataBankV8Compat(app){
 app.get('/api/iran/v8/bank-accounts',requireRole('ACCOUNTANT','FINANCE_MANAGER'),wrap(async(req,res)=>{
   const [r]=await pool.execute(`SELECT id,company_id,branch_id,code,code account_code,bank_name,account_title,account_type,branch_code,branch_name,account_no,iban,card_no,account_holder,currency,opening_balance,current_balance,phone,fax,address,notes,is_active,gl_account_id FROM bank_accounts WHERE company_id=? ORDER BY is_active DESC,bank_name,code`,[req.user.companyId]);
   res.json(r);
 }));
 app.post('/api/iran/v8/bank-accounts',requireRole('FINANCE_MANAGER'),wrap(async(req,res)=>{
   const b=req.body||{};if(!txt(b.accountCode)||!txt(b.bankName)||!txt(b.accountNo)){const e=new Error('کد حساب، نام بانک و شماره حساب الزامی است.');e.status=422;throw e}
   const title=txt(b.accountTitle)||txt(b.accountHolder)||`${txt(b.bankName)} - ${txt(b.accountNo)}`;
   const [r]=await pool.execute(`INSERT INTO bank_accounts(company_id,branch_id,code,bank_name,account_title,account_type,branch_code,branch_name,account_no,iban,card_no,account_holder,currency,opening_balance,current_balance,phone,fax,address,notes,is_active) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,1)`,[req.user.companyId,b.branchId||null,txt(b.accountCode),txt(b.bankName),title,b.accountType||null,b.branchCode||null,b.branchName||null,txt(b.accountNo),b.iban||null,b.cardNo||null,b.accountHolder||null,b.currency||'IRR',n(b.openingBalance),n(b.openingBalance),b.phone||null,b.fax||null,b.address||null,b.notes||null]);
   res.status(201).json({id:r.insertId});
 }));
}
