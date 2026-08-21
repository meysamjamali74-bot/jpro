import mysql from 'mysql2/promise';
import assert from 'node:assert/strict';
const base=process.env.TEST_BASE_URL||'http://127.0.0.1:8080';
const db=await mysql.createConnection({host:process.env.MYSQL_HOST||'127.0.0.1',port:Number(process.env.MYSQL_PORT||3306),user:process.env.MYSQL_USER||'tarazpad',password:process.env.MYSQL_PASSWORD||'',database:process.env.MYSQL_DATABASE||'tarazpad',decimalNumbers:true});
async function api(path,{token,method='GET',body,allow=[]}={}){const r=await fetch(base+path,{method,headers:{'content-type':'application/json',...(token?{authorization:`Bearer ${token}`}:{})},body:body===undefined?undefined:JSON.stringify(body)}),text=await r.text();let data;try{data=JSON.parse(text)}catch{data=text}if(!r.ok&&!allow.includes(r.status))throw new Error(`${method} ${path} -> ${r.status}: ${typeof data==='string'?data:JSON.stringify(data)}`);return{status:r.status,data}}
async function login(email,password){return(await api('/api/auth/login',{method:'POST',body:{email,password}})).data.token}
async function user(admin,name,email,password,roles){return(await api('/api/iran/admin/users',{token:admin,method:'POST',body:{fullName:name,email,password,roleCodes:roles}})).data}
const pFmt=new Intl.DateTimeFormat('en-US-u-ca-persian',{year:'numeric',month:'numeric',day:'numeric',timeZone:'UTC'});
const pparts=d=>Object.fromEntries(pFmt.formatToParts(new Date(d)).filter(x=>x.type!=='literal').map(x=>[x.type,Number(x.value)]));
const step=x=>console.log(`\n[PHASE16] ${x}`);
try{
 step('fresh startup and users');
 assert.equal((await api('/api/health')).data.ok,true);
 const admin=await login(process.env.TARAZPAD_ADMIN_EMAIL,'Strong_P16_Admin_2026!');
 const accountant=await user(admin,'حسابدار بستن دوره','p16-accountant@tarazpad.test','Strong_P16_Accountant!',['ACCOUNTANT']);
 const fin1=await user(admin,'بازبین مالی','p16-fin1@tarazpad.test','Strong_P16_Fin1_2026!',['FINANCE_MANAGER']);
 const fin2=await user(admin,'تأییدکننده مالی','p16-fin2@tarazpad.test','Strong_P16_Fin2_2026!',['FINANCE_MANAGER']);
 const AT=await login('p16-accountant@tarazpad.test','Strong_P16_Accountant!'),F1=await login('p16-fin1@tarazpad.test','Strong_P16_Fin1_2026!'),F2=await login('p16-fin2@tarazpad.test','Strong_P16_Fin2_2026!');
 const me=(await api('/api/me',{token:admin})).data.user,adminId=Number(me.sub);

 step('create Jalali fiscal year and choose period 5');
 const fy=(await api('/api/iran/finance/fiscal-years',{token:F1,method:'POST',body:{yearNo:1405,title:'سال مالی ۱۴۰۵'}})).data;assert.equal(fy.periodCount,12);
 const years=(await api('/api/iran/finance/fiscal-years',{token:AT})).data,year=years.find(x=>Number(x.id)===Number(fy.id)),period=year.periods.find(x=>Number(x.period_no)===5);assert.ok(period);const ps=pparts(period.start_date);assert.deepEqual({year:ps.year,month:ps.month,day:ps.day},{year:1405,month:5,day:1});

 step('seed balanced posted ledger transactions inside period');
 const [[ar]]=await db.query(`SELECT id FROM accounts WHERE company_id=1 AND code='110100'`),[[inv]]=await db.query(`SELECT id FROM accounts WHERE company_id=1 AND code='130100'`),[[sales]]=await db.query(`SELECT id FROM accounts WHERE company_id=1 AND code='410100'`),[[cogs]]=await db.query(`SELECT id FROM accounts WHERE company_id=1 AND code='510100'`);assert.ok(ar&&inv&&sales&&cogs);
 const entryDate=String(period.start_date).slice(0,10);
 const [j1]=await db.execute(`INSERT INTO journal_entries(company_id,entry_no,entry_date,posting_date,status,source_type,description,created_by,posted_at) VALUES (1,'P16-SALE-1',?,?, 'POSTED','P16_TEST','فروش کنترل صورت مالی',?,NOW())`,[entryDate,entryDate,adminId]);await db.execute(`INSERT INTO journal_lines(journal_entry_id,account_id,debit,credit,description) VALUES (?,?,1000000,0,'مطالبات'),(?,?,0,1000000,'فروش')`,[j1.insertId,ar.id,j1.insertId,sales.id]);
 const [j2]=await db.execute(`INSERT INTO journal_entries(company_id,entry_no,entry_date,posting_date,status,source_type,description,created_by,posted_at) VALUES (1,'P16-COGS-1',?,?, 'POSTED','P16_TEST','بهای تمام‌شده کنترل',?,NOW())`,[entryDate,entryDate,adminId]);await db.execute(`INSERT INTO journal_lines(journal_entry_id,account_id,debit,credit,description) VALUES (?,?,400000,0,'بهای تمام‌شده'),(?,?,0,400000,'کاهش موجودی')`,[j2.insertId,cogs.id,j2.insertId,inv.id]);

 step('P&L, balance sheet, trial balance and ledger drill-through');
 const pl=(await api(`/api/iran/finance/profit-loss?dateFrom=${entryDate}&dateTo=${String(period.end_date).slice(0,10)}`,{token:AT})).data;assert.equal(Number(pl.current.sections.OPERATING_REVENUE),1000000);assert.equal(Number(pl.current.sections.COST_OF_SALES),400000);assert.equal(Number(pl.current.netProfit),600000);assert.equal(pl.current.unmapped.length,0);
 const bs=(await api(`/api/iran/finance/balance-sheet?asOf=${String(period.end_date).slice(0,10)}`,{token:AT})).data;assert.equal(Number(bs.current.totalAssets),600000);assert.equal(Number(bs.current.currentEarnings),600000);assert.ok(Math.abs(Number(bs.current.balanceDifference))<1);
 const tb=(await api(`/api/iran/finance/trial-balance-v6?dateFrom=${entryDate}&dateTo=${String(period.end_date).slice(0,10)}&level=9`,{token:AT})).data;assert.equal(Number(tb.totalDebit),1400000);assert.equal(Number(tb.totalCredit),1400000);
 const ledger=(await api(`/api/iran/finance/account-ledger/${ar.id}?dateFrom=${entryDate}&dateTo=${String(period.end_date).slice(0,10)}`,{token:AT})).data;assert.equal(ledger.rows.length,1);assert.equal(Number(ledger.rows[0].journal_entry_id),Number(j1.insertId));
 const drill=(await api(`/api/iran/finance/journals/${j1.insertId}/drill-through`,{token:AT})).data;assert.equal(drill.lines.length,2);assert.equal(drill.source.type,'P16_TEST');
 const snap=(await api('/api/iran/finance/report-snapshots',{token:F1,method:'POST',body:{reportType:'PROFIT_LOSS',periodStart:entryDate,asOfDate:String(period.end_date).slice(0,10)}})).data;assert.match(snap.sourceHash,/^[a-f0-9]{64}$/);

 step('cash flow never silently classifies unmapped flows');
 const cf=(await api(`/api/iran/finance/cash-flow?dateFrom=${entryDate}&dateTo=${String(period.end_date).slice(0,10)}`,{token:AT})).data;assert.ok(Array.isArray(cf.unmapped));assert.match(cf.sourceHash,/^[a-f0-9]{64}$/);

 step('close checklist blocks until management review is resolved');
 const run=(await api('/api/iran/finance/close-runs',{token:AT,method:'POST',body:{fiscalPeriodId:period.id,closeMode:'HARD'}})).data;
 const checked=(await api(`/api/iran/finance/close-runs/${run.id}/check`,{token:AT,method:'POST',body:{}})).data;assert.equal(checked.status,'BLOCKED');assert.ok(checked.blockers>=1);
 let results=(await api(`/api/iran/finance/close-runs/${run.id}/results`,{token:AT})).data;const mgmt=results.find(x=>x.checklist_code==='MANAGEMENT_REVIEW');assert.ok(mgmt&&mgmt.status==='MANUAL_PENDING');
 await api(`/api/iran/finance/close-results/${mgmt.id}/resolve`,{token:F1,method:'POST',body:{action:'MANUAL_DONE',note:'گزارش‌های نهایی و تراز دوره توسط مدیر مالی بررسی شد.'}});
 const reviewed=(await api(`/api/iran/finance/close-runs/${run.id}/review`,{token:F1,method:'POST',body:{}})).data;assert.equal(reviewed.status,'REVIEWED');
 const approved=(await api(`/api/iran/finance/close-runs/${run.id}/approve`,{token:F2,method:'POST',body:{}})).data;assert.equal(approved.status,'APPROVED');
 const closed=(await api(`/api/iran/finance/close-runs/${run.id}/close`,{token:F2,method:'POST',body:{}})).data;assert.equal(closed.periodStatus,'HARD_CLOSED');

 step('database hard-close blocks header and line mutation');
 await assert.rejects(()=>db.execute(`INSERT INTO journal_entries(company_id,entry_no,entry_date,posting_date,status,source_type,description,created_by,posted_at) VALUES (1,'P16-BLOCKED',?,?, 'POSTED','P16_TEST','نباید ثبت شود',?,NOW())`,[entryDate,entryDate,adminId]),/ACCOUNTING_PERIOD_HARD_CLOSED/);
 await assert.rejects(()=>db.execute(`UPDATE journal_entries SET description='نباید تغییر کند' WHERE id=?`,[j1.insertId]),/ACCOUNTING_PERIOD_HARD_CLOSED/);
 await assert.rejects(()=>db.execute(`INSERT INTO journal_lines(journal_entry_id,account_id,debit,credit) VALUES (?,?,1,0)`,[j1.insertId,ar.id]),/ACCOUNTING_PERIOD_HARD_CLOSED/);
 await assert.rejects(()=>db.execute(`DELETE FROM journal_lines WHERE journal_entry_id=? LIMIT 1`,[j1.insertId]),/ACCOUNTING_PERIOD_HARD_CLOSED/);

 step('independent reopen restores posting capability and keeps audit reason');
 const reopened=(await api(`/api/iran/finance/close-runs/${run.id}/reopen`,{token:admin,method:'POST',body:{reason:'بازگشایی کنترل‌شده جهت ثبت تعدیل حسابرسی پایان دوره'}})).data;assert.equal(reopened.status,'REOPENED');
 const [j3]=await db.execute(`INSERT INTO journal_entries(company_id,entry_no,entry_date,posting_date,status,source_type,description,created_by,posted_at) VALUES (1,'P16-AFTER-REOPEN',?,?, 'POSTED','P16_TEST','ثبت مجاز پس از بازگشایی',?,NOW())`,[entryDate,entryDate,adminId]);assert.ok(j3.insertId);
 const [[rr]]=await db.execute(`SELECT reopen_reason FROM period_close_runs WHERE id=?`,[run.id]);assert.match(rr.reopen_reason,/بازگشایی/);

 step('final reporting remains balanced');
 const [[bal]]=await db.query(`SELECT COALESCE(SUM(jl.debit-jl.credit),0) diff FROM journal_lines jl JOIN journal_entries je ON je.id=jl.journal_entry_id WHERE je.company_id=1 AND je.status IN ('POSTED','LOCKED')`);assert.ok(Math.abs(Number(bal.diff))<1);
 console.log('\nPHASE16_FINANCIAL_REPORTING_PASS');
}finally{await db.end()}
