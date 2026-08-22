import mysql from 'mysql2/promise';
import assert from 'node:assert/strict';
const base=process.env.TEST_BASE_URL||'http://127.0.0.1:8080';
const db=await mysql.createConnection({host:process.env.MYSQL_HOST||'127.0.0.1',port:Number(process.env.MYSQL_PORT||3306),user:process.env.MYSQL_USER||'tarazpad',password:process.env.MYSQL_PASSWORD||'',database:process.env.MYSQL_DATABASE||'tarazpad',decimalNumbers:true});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function api(path,{token,method='GET',body,allow=[]}={}){const r=await fetch(base+path,{method,headers:{'content-type':'application/json',...(token?{authorization:`Bearer ${token}`}:{})},body:body===undefined?undefined:JSON.stringify(body)});const text=await r.text();let data;try{data=JSON.parse(text)}catch{data=text}if(!r.ok&&!allow.includes(r.status))throw new Error(`${method} ${path} -> ${r.status}: ${typeof data==='string'?data:JSON.stringify(data)}`);return{status:r.status,data}}
async function login(email,password){return (await api('/api/auth/login',{method:'POST',body:{email,password}})).data.token}
async function makeUser(admin,fullName,email,password,roleCodes){return (await api('/api/iran/admin/users',{token:admin,method:'POST',body:{fullName,email,password,roleCodes}})).data}
async function pollJob(admin,id,timeout=90000){const start=Date.now();while(Date.now()-start<timeout){const x=(await api('/api/iran/system/backup-center',{token:admin})).data,j=x.jobs.find(v=>Number(v.id)===Number(id));if(j&&['SUCCESS','FAILED'].includes(j.status))return{job:j,center:x};await sleep(1500)}throw new Error(`maintenance job ${id} timeout`)}
function step(name){console.log(`\n[PHASE15] ${name}`)}
try{
 step('health and fresh-install seed context');
 assert.equal((await api('/api/health')).data.ok,true);
 const admin=await login(process.env.TARAZPAD_ADMIN_EMAIL,'Strong_P15_Admin_2026!');
 const [[seed]]=await db.query(`SELECT (SELECT COUNT(*) FROM accounts WHERE company_id=1) accounts,(SELECT COUNT(*) FROM company_accounting_policies WHERE company_id=1) policies,(SELECT COUNT(*) FROM kpi_definitions WHERE company_id=1) kpis`);
 assert.ok(seed.accounts>=8,'fresh install accounts were not seeded');assert.equal(seed.policies,1);assert.ok(seed.kpis>=10);

 step('create separated operational users');
 const accountant=await makeUser(admin,'حسابدار فاز ۱۵','p15-accountant@tarazpad.test','Strong_P15_Accountant!',['ACCOUNTANT']);
 const finance1=await makeUser(admin,'مدیر مالی یک','p15-fin1@tarazpad.test','Strong_P15_Fin1_2026!',['FINANCE_MANAGER']);
 const finance2=await makeUser(admin,'مدیر مالی دو','p15-fin2@tarazpad.test','Strong_P15_Fin2_2026!',['FINANCE_MANAGER']);
 const warehouse=await makeUser(admin,'مدیر انبار فاز ۱۵','p15-wh@tarazpad.test','Strong_P15_WH_2026!',['WAREHOUSE_MANAGER']);
 const salesperson=await makeUser(admin,'فروشنده فاز ۱۵','p15-sales@tarazpad.test','Strong_P15_Sales_2026!',['SALES_PERSON']);
 const salesManager=await makeUser(admin,'مدیر فروش فاز ۱۵','p15-salesmgr@tarazpad.test','Strong_P15_SalesMgr!',['SALES_MANAGER']);
 const hr=await makeUser(admin,'مدیر منابع انسانی فاز ۱۵','p15-hr@tarazpad.test','Strong_P15_HR_2026!',['HR_MANAGER']);
 const conflict=await makeUser(admin,'کاربر متعارض کنترلی','p15-conflict@tarazpad.test','Strong_P15_Conflict!',['SALES_PERSON','FINANCE_MANAGER']);
 const consReviewer=await makeUser(admin,'بازبین تلفیق','p15-cons-review@tarazpad.test','Strong_P15_ConsReview!',['SUPER_ADMIN']);
 const consFinal=await makeUser(admin,'نهایی‌کننده تلفیق','p15-cons-final@tarazpad.test','Strong_P15_ConsFinal!',['SUPER_ADMIN']);
 const AT=await login('p15-accountant@tarazpad.test','Strong_P15_Accountant!'),F1=await login('p15-fin1@tarazpad.test','Strong_P15_Fin1_2026!'),F2=await login('p15-fin2@tarazpad.test','Strong_P15_Fin2_2026!'),WH=await login('p15-wh@tarazpad.test','Strong_P15_WH_2026!'),SA=await login('p15-sales@tarazpad.test','Strong_P15_Sales_2026!'),SM=await login('p15-salesmgr@tarazpad.test','Strong_P15_SalesMgr!'),HR=await login('p15-hr@tarazpad.test','Strong_P15_HR_2026!'),CR=await login('p15-cons-review@tarazpad.test','Strong_P15_ConsReview!'),CF=await login('p15-cons-final@tarazpad.test','Strong_P15_ConsFinal!');

 step('FIFO purchase receipt and accounting');
 await api('/api/iran/accounting-policy',{token:F1,method:'PUT',body:{inventoryValuation:'FIFO',inventoryIssuePolicy:'FULFILLMENT',revenueRecognition:'INVOICE',allowNegativeInventory:false}});
 const wh=(await api('/api/inventory/warehouses',{token:WH,method:'POST',body:{code:'P15-WH',name:'انبار کنترل فاز ۱۵',warehouseType:'GENERAL'}})).data.id;
 const customer=(await api('/api/iran/parties',{token:admin,method:'POST',body:{name:'مشتری کنترل فاز ۱۵',partyType:'LEGAL',code:'P15-CUS',mobile:'09121234567',nationalId:'14009999991',economicCode:'499999999991',postalCode:'1499999991',roles:['CUSTOMER'],creditLimit:100000000}})).data.id;
 const supplier=(await api('/api/iran/parties',{token:admin,method:'POST',body:{name:'تامین کننده کنترل فاز ۱۵',partyType:'LEGAL',code:'P15-SUP',nationalId:'14009999992',economicCode:'499999999992',postalCode:'1499999992',roles:['SUPPLIER']}})).data.id;
 const product=(await api('/api/iran/products',{token:WH,method:'POST',body:{sku:'P15-PRD',name:'کالای FIFO کنترل',unit:'عدد',purchasePrice:70000,salePrice:100000,vatStatus:'EXEMPT',defaultVatRate:0,productType:'GOODS'}})).data.id;
 const po=(await api('/api/procurement/orders',{token:admin,method:'POST',body:{supplierPartyId:supplier,warehouseId:wh,poDate:'2026-08-01',lines:[{productId:product,qty:10,unitPrice:70000,discount:0,tax:0}]}})).data.id;
 const approval=(await api(`/api/procurement/orders/${po}/submit`,{token:admin,method:'POST',body:{}})).data.approvalRequestId;
 assert.equal((await api(`/api/workflow/approvals/${approval}/decision`,{token:F1,method:'POST',body:{action:'APPROVE'}})).data.status,'APPROVED');
 const ctx=(await api(`/api/iran/procurement/context?purchaseOrderId=${po}`,{token:admin})).data,pol=ctx.poLines[0].id;
 const gr=(await api('/api/procurement/goods-receipts',{token:WH,method:'POST',body:{purchaseOrderId:po,warehouseId:wh,receiptDate:'2026-08-02',lines:[{purchaseOrderLineId:pol,receivedQty:10,acceptedQty:10,unitCost:70000}]}})).data.id;
 assert.equal((await api(`/api/iran/goods-receipts/${gr}/post`,{token:F1,method:'POST',body:{}})).data.receivedValue,700000);
 const [[layer]]=await db.execute(`SELECT COUNT(*) cnt,SUM(remaining_qty) qty FROM inventory_cost_layers WHERE company_id=1 AND warehouse_id=? AND product_id=?`,[wh,product]);assert.equal(layer.cnt,1);assert.equal(Number(layer.qty),10);

 step('fulfillment -> FIFO issue -> posted invoice -> BI');
 const inv=(await api('/api/iran/sales-invoices',{token:SA,method:'POST',body:{customerPartyId:customer,invoiceDate:'2026-08-10',dueDate:'2026-08-20',invoiceClassification:'NON_OFFICIAL',settlementType:'CREDIT',salespersonUserId:salesperson.id,lines:[{productId:product,qty:2,unitPrice:100000,vatStatus:'EXEMPT',vatRate:0}]}})).data.id;
 const ful=(await api('/api/iran/sales/fulfillments',{token:WH,method:'POST',body:{salesInvoiceId:inv,warehouseId:wh}})).data.id;
 await api(`/api/iran/sales/fulfillments/${ful}/reserve`,{token:WH,method:'POST',body:{}});await api(`/api/iran/sales/fulfillments/${ful}/pick`,{token:WH,method:'POST',body:{}});await api(`/api/iran/sales/fulfillments/${ful}/pack`,{token:WH,method:'POST',body:{}});
 const issued=(await api(`/api/iran/sales/fulfillments/${ful}/issue`,{token:WH,method:'POST',body:{}})).data;assert.equal(issued.valuationMethod,'FIFO');assert.equal(Number(issued.actualCost),140000);
 const posted=(await api(`/api/iran/sales-invoices/${inv}/post`,{token:F1,method:'POST',body:{}})).data;assert.equal(posted.ok,true);assert.equal(Number(posted.amounts.COGS_TOTAL),140000);
 const [[bal]]=await db.execute(`SELECT on_hand_qty FROM inventory_balances WHERE company_id=1 AND warehouse_id=? AND product_id=? AND batch_no IS NULL AND expiry_date IS NULL`,[wh,product]);assert.equal(Number(bal.on_hand_qty),8);
 const [[layer2]]=await db.execute(`SELECT remaining_qty FROM inventory_cost_layers WHERE company_id=1 AND warehouse_id=? AND product_id=?`,[wh,product]);assert.equal(Number(layer2.remaining_qty),8);
 assert.equal(Number((await api('/api/iran/bi/kpi/GROSS_PROFIT?dateFrom=2026-08-01&dateTo=2026-08-31',{token:F1})).data.value),60000);
 assert.equal(Number((await api('/api/iran/bi/kpi/NET_SALES?dateFrom=2026-08-01&dateTo=2026-08-31',{token:F1})).data.value),200000);
 const catalog=(await api('/api/iran/bi/widget-catalog',{token:F1})).data;assert.ok(catalog.length>=15);
 const dash=(await api('/api/iran/bi/dashboards',{token:F1,method:'POST',body:{title:'داشبورد کنترل فاز ۱۵'}})).data.id;
 await api(`/api/iran/bi/dashboards/${dash}/widgets`,{token:F1,method:'PUT',body:{widgets:[{widgetCode:'FIN_AR',x:0,y:0,width:4,height:2},{widgetCode:'SALES_NET',x:4,y:0,width:4,height:2}]}});const dashboards=(await api('/api/iran/bi/dashboards',{token:F1})).data;assert.equal(dashboards.find(x=>Number(x.id)===Number(dash)).widgets.length,2);

 step('field-level security and SoD');
 await api('/api/iran/security/field-policies',{token:admin,method:'POST',body:{entityType:'PARTY',fieldName:'mobile',roleCode:'SALES_PERSON',accessMode:'MASKED',maskPattern:'PHONE'}});
 const plist=(await api('/api/iran/parties?q=P15-CUS',{token:SA})).data.rows;assert.ok(plist[0].mobile.endsWith('4567'));assert.ok(plist[0].mobile.includes('*'));
 const conflicts=(await api('/api/iran/security/sod-conflicts',{token:admin})).data;assert.ok(conflicts.some(x=>Number(x.user_id)===Number(conflict.id)&&x.code==='SOD_SALES_FINANCE'));

 step('multi-currency journal and repeat-safe FX revaluation');
 await api('/api/iran/fx/rates',{token:F1,method:'POST',body:{rateDate:'2026-08-15',fromCurrency:'USD',toCurrency:'IRR',rateType:'CUSTOM',rate:100000,source:'phase15'}});
 await api('/api/iran/fx/rates',{token:F1,method:'POST',body:{rateDate:'2026-08-20',fromCurrency:'USD',toCurrency:'IRR',rateType:'CLOSING',rate:110000,source:'phase15'}});
 const [[arAcc]]=await db.query(`SELECT id FROM accounts WHERE company_id=1 AND code='110100'`),[[salesAcc]]=await db.query(`SELECT id FROM accounts WHERE company_id=1 AND code='410100'`);
 const fxj=(await api('/api/iran/fx/manual-journals',{token:AT,method:'POST',body:{entryDate:'2026-08-15',description:'سند ارزی کنترل',lines:[{accountId:arAcc.id,currencyCode:'USD',foreignDebit:100,foreignCredit:0,exchangeRate:100000},{accountId:salesAcc.id,currencyCode:'IRR',foreignDebit:0,foreignCredit:10000000,exchangeRate:1}]}})).data.id;
 await api(`/api/iran/fx/manual-journals/${fxj}/check`,{token:F1,method:'POST',body:{}});await api(`/api/iran/fx/manual-journals/${fxj}/approve`,{token:F2,method:'POST',body:{}});await api(`/api/iran/fx/manual-journals/${fxj}/post`,{token:admin,method:'POST',body:{}});
 const reval=(await api('/api/iran/fx/revaluations/calculate',{token:F1,method:'POST',body:{revaluationDate:'2026-08-20',rateType:'CLOSING'}})).data;assert.equal(reval.lineCount,1);assert.equal(Number(reval.gainAmount),1000000);
 await api(`/api/iran/fx/revaluations/${reval.id}/review`,{token:F2,method:'POST',body:{}});await api(`/api/iran/fx/revaluations/${reval.id}/post`,{token:admin,method:'POST',body:{}});
 const reval2=(await api('/api/iran/fx/revaluations/calculate',{token:F1,method:'POST',body:{revaluationDate:'2026-08-20',rateType:'CLOSING'}})).data;assert.equal(reval2.lineCount,0,'same closing rate must not revalue twice');

 step('commission -> employee mapping -> payroll');
 const emp=(await api('/api/iran/hr/employees',{token:HR,method:'POST',body:{personnelNo:'P15-E001',name:'فروشنده پرسنلی کنترل',nationalNo:'0011223399',insuranceNo:'P15-INS',hireDate:'2026-03-21',maritalStatus:'MARRIED',childrenCount:0}})).data.partyId;
 await api('/api/iran/hr/contracts',{token:HR,method:'POST',body:{employeePartyId:emp,contractNo:'P15-CTR-1',contractType:'FIXED_TERM',startDate:'2026-03-21',endDate:'2027-03-20',baseSalaryMonthly:250000000,insuranceIncluded:true,taxIncluded:true,status:'ACTIVE'}});
 await api('/api/iran/payroll/employee-user-links',{token:HR,method:'POST',body:{userId:salesperson.id,employeePartyId:emp,effectiveFrom:'2026-03-21'}});
 const rule=(await api('/api/iran/commissions/rules',{token:admin,method:'POST',body:{title:'پورسانت فروش فاز ۱۵',basis:'NET_SALES',baseRate:2,assignments:[{salespersonUserId:salesperson.id,effectiveFrom:'2026-08-01'}]}})).data.id;assert.ok(rule);
 const run=(await api('/api/iran/commissions/run',{token:admin,method:'POST',body:{periodStart:'2026-08-01',periodEnd:'2026-08-31',salespersonUserId:salesperson.id}})).data;assert.ok(run.length>=1);const comm=run[0];await api(`/api/iran/commissions/results/${comm.id}/review`,{token:SM,method:'POST',body:{}});await api(`/api/iran/commissions/results/${comm.id}/approve`,{token:F1,method:'POST',body:{}});
 await api('/api/iran/payroll/attendance',{token:HR,method:'POST',body:{employeePartyId:emp,yearNo:1405,monthNo:5,calendarDays:31,workDays:31,overtimeHours:0}});
 const batch=(await api('/api/iran/payroll/batches',{token:HR,method:'POST',body:{yearNo:1405,monthNo:5,title:'حقوق فاز ۱۵'}})).data.id;
 const calc=(await api(`/api/iran/payroll/batches/${batch}/calculate`,{token:HR,method:'POST',body:{}})).data;assert.ok(calc.employeeCount>=1);
 const imported=(await api(`/api/iran/payroll/batches/${batch}/import-commissions`,{token:F1,method:'POST',body:{}})).data;assert.ok(imported.count>=1);assert.ok(imported.total>0);
 const links=(await api('/api/iran/payroll/commission-links',{token:F1})).data;assert.ok(links.some(x=>Number(x.payroll_batch_id)===Number(batch)&&Number(x.employee_party_id)===Number(emp)));

 step('real backup + SHA verification + restore test');
 const bj=(await api('/api/iran/system/backup-jobs',{token:admin,method:'POST',body:{jobType:'FULL_BACKUP',priority:1}})).data.id,bres=await pollJob(admin,bj,120000);assert.equal(bres.job.status,'SUCCESS',bres.job.error_text||'backup failed');const backupId=JSON.parse(bres.job.result_json).backupRunId;assert.ok(backupId);
 const rj=(await api('/api/iran/system/backup-jobs',{token:admin,method:'POST',body:{jobType:'RESTORE_TEST',priority:1,payload:{backupRunId:backupId}}})).data.id,rres=await pollJob(admin,rj,120000);assert.equal(rres.job.status,'SUCCESS',rres.job.error_text||'restore test failed');assert.ok(rres.center.restoreTests.some(x=>Number(x.backup_run_id)===Number(backupId)&&x.status==='SUCCESS'));

 step('intercompany reconciliation and three-person consolidation');
 const [c2r]=await db.execute(`INSERT INTO companies(code,name,base_currency,timezone,is_active) VALUES ('P15C2','شرکت دوم کنترل','IRR','Asia/Tehran',1)`);const c2=c2r.insertId;const [u2r]=await db.execute(`INSERT INTO users(company_id,full_name,email,password_hash,is_active) VALUES (?,'کاربر سیستمی شرکت دوم','__p15c2__@tarazpad.local','x',0)`,[c2]);const u2=u2r.insertId;
 for(const [code,title,nature,type] of [['110100','دارایی کنترل','DEBIT','ASSET'],['120900','دریافتنی بین شرکتی','DEBIT','ASSET'],['220900','پرداختنی بین شرکتی','CREDIT','LIABILITY']])await db.execute(`INSERT INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting) VALUES (?,?,?,3,?,?,1)`,[c2,code,title,nature,type]);
 const [[df1]]=await db.query(`SELECT id FROM accounts WHERE company_id=1 AND code='120900'`),[[dt1]]=await db.query(`SELECT id FROM accounts WHERE company_id=1 AND code='220900'`),[[a1]]=await db.query(`SELECT id FROM accounts WHERE company_id=1 AND code='110100'`),[[a2]]=await db.execute(`SELECT id FROM accounts WHERE company_id=? AND code='110100'`,[c2]),[[dt2]]=await db.execute(`SELECT id FROM accounts WHERE company_id=? AND code='220900'`,[c2]);
 const [j1r]=await db.execute(`INSERT INTO journal_entries(company_id,entry_no,entry_date,status,source_type,description,created_by,posted_at) VALUES (1,'P15-IC-1','2026-08-20','POSTED','INTERCOMPANY','بین شرکتی کنترل',?,NOW())`,[Number((await api('/api/me',{token:admin})).data.user.sub)]);await db.execute(`INSERT INTO journal_lines(journal_entry_id,account_id,debit,credit) VALUES (?,?,500000,0),(?,?,0,500000)`,[j1r.insertId,df1.id,j1r.insertId,a1.id]);
 const [j2r]=await db.execute(`INSERT INTO journal_entries(company_id,entry_no,entry_date,status,source_type,description,created_by,posted_at) VALUES (?,'P15-IC-2','2026-08-20','POSTED','INTERCOMPANY','بین شرکتی کنترل',?,NOW())`,[c2,u2]);await db.execute(`INSERT INTO journal_lines(journal_entry_id,account_id,debit,credit) VALUES (?,?,500000,0),(?,?,0,500000)`,[j2r.insertId,a2.id,j2r.insertId,dt2.id]);
 await api('/api/iran/intercompany/relationships',{token:admin,method:'POST',body:{counterpartyCompanyId:c2,dueFromAccountId:df1.id,dueToAccountId:dt1.id}});const ict=(await api('/api/iran/intercompany/transactions/link',{token:admin,method:'POST',body:{targetCompanyId:c2,transactionDate:'2026-08-20',sourceType:'MANUAL_IC',sourceId:1,amount:500000,currencyCode:'IRR',sourceJournalEntryId:j1r.insertId}})).data.id;await api(`/api/iran/intercompany/transactions/${ict}/reconcile`,{token:admin,method:'POST',body:{targetJournalEntryId:j2r.insertId}});
 const con=(await api('/api/iran/consolidation/calculate',{token:admin,method:'POST',body:{reportingDate:'2026-08-20',reportingCurrency:'IRR',companyIds:[1,c2]}})).data;assert.equal(Number(con.intercompanyDifference),0);assert.equal(Number(con.eliminationAmount),500000);await api(`/api/iran/consolidation/runs/${con.id}/review`,{token:CR,method:'POST',body:{}});assert.equal((await api(`/api/iran/consolidation/runs/${con.id}/finalize`,{token:CF,method:'POST',body:{tolerance:1}})).data.status,'FINAL');

 step('global accounting balance and system health');
 const tb=(await api('/api/finance/trial-balance',{token:F1})).data;const dr=tb.reduce((s,x)=>s+Number(x.debit||0),0),cr=tb.reduce((s,x)=>s+Number(x.credit||0),0);assert.ok(Math.abs(dr-cr)<1,`trial balance difference ${dr-cr}`);
 const hj=(await api('/api/iran/system/backup-jobs',{token:admin,method:'POST',body:{jobType:'INTEGRITY_CHECK',priority:1}})).data.id;const hres=await pollJob(admin,hj);assert.equal(hres.job.status,'SUCCESS');
 console.log('\nPHASE15_E2E_PASS');
}finally{await db.end()}
