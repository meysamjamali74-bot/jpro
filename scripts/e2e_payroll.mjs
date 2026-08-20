const base=process.env.TARAZPAD_URL||'http://127.0.0.1:8080';
const email=process.env.TARAZPAD_ADMIN_EMAIL||'strict@tarazpad.test';
const password=process.env.TARAZPAD_ADMIN_PASSWORD||'Strong_Strict_2026!';
const log=(s,d='')=>console.log(`[PAYROLL-E2E] ${s}${d?` :: ${typeof d==='string'?d:JSON.stringify(d)}`:''}`);
const assert=(v,m,d)=>{if(!v){const e=new Error(m);e.data=d;throw e}};
async function req(path,{token,method='GET',body}={}){const r=await fetch(base+path,{method,headers:{...(token?{authorization:`Bearer ${token}`}:{}) ,...(body!==undefined?{'content-type':'application/json'}:{})},body:body===undefined?undefined:JSON.stringify(body)});const text=await r.text();let data;try{data=JSON.parse(text)}catch{data=text}if(!r.ok){const e=new Error(`${method} ${path} -> ${r.status} ${typeof data==='string'?data:JSON.stringify(data)}`);e.data=data;throw e}return data}
async function main(){
 const auth=await req('/api/auth/login',{method:'POST',body:{email,password}}),token=auth.token;assert(token,'توکن مدیریت دریافت نشد',auth);log('LOGIN_OK');
 const stamp=Date.now().toString().slice(-7);
 const legal=await req('/api/iran/payroll/legal-parameters',{token});assert(legal.length>=1,'پارامتر قانونی حقوق وجود ندارد',legal);log('LEGAL_PARAMETERS_OK',legal[0].jalali_year);
 const emp=await req('/api/iran/hr/employees',{token,method:'POST',body:{personnelNo:`PE-${stamp}`,name:'کارمند تست حقوق',nationalNo:`00${stamp}1`,insuranceNo:`INS-${stamp}`,hireDate:'2026-03-21',maritalStatus:'MARRIED',childrenCount:1}});assert(emp.partyId,'کارمند ایجاد نشد',emp);log('EMPLOYEE_OK',emp.partyId);
 const ctr=await req('/api/iran/hr/contracts',{token,method:'POST',body:{employeePartyId:emp.partyId,contractNo:`CTR-${stamp}`,contractType:'FIXED_TERM',startDate:'2026-03-21',endDate:'2027-03-20',baseSalaryMonthly:250000000,insuranceIncluded:true,taxIncluded:true,status:'ACTIVE'}});assert(ctr.id,'قرارداد ایجاد نشد',ctr);log('CONTRACT_OK',ctr.id);
 const att=await req('/api/iran/payroll/attendance',{token,method:'POST',body:{employeePartyId:emp.partyId,yearNo:1405,monthNo:5,calendarDays:31,workDays:31,overtimeHours:10,paidLeaveDays:0,absenceDays:0}});assert(att.ok,'کارکرد ثبت نشد',att);log('ATTENDANCE_OK');
 const loan=await req('/api/iran/payroll/loans',{token,method:'POST',body:{employeePartyId:emp.partyId,loanNo:`LOAN-${stamp}`,loanType:'LOAN',principalAmount:12000000,installmentAmount:1000000,startDate:'2026-03-21'}});assert(loan.id,'وام ثبت نشد',loan);log('LOAN_OK',loan.id);
 const batch=await req('/api/iran/payroll/batches',{token,method:'POST',body:{yearNo:1405,monthNo:5,title:`حقوق E2E ${stamp}`}});assert(batch.id,'دوره حقوق ایجاد نشد',batch);log('BATCH_OK',batch.id);
 const calc=await req(`/api/iran/payroll/batches/${batch.id}/calculate`,{token,method:'POST',body:{}});assert(calc.employeeCount>=1&&Number(calc.totalGross)>0&&Number(calc.totalNet)>0,'محاسبه حقوق نامعتبر است',calc);log('CALCULATED',{gross:calc.totalGross,net:calc.totalNet,tax:calc.totalTax});
 const review=await req(`/api/iran/payroll/batches/${batch.id}/review`,{token,method:'POST',body:{}});assert(review.status==='REVIEWED','بازبینی حقوق انجام نشد',review);log('REVIEWED');
 const approve=await req(`/api/iran/payroll/batches/${batch.id}/approve`,{token,method:'POST',body:{}});assert(approve.status==='APPROVED','تأیید حقوق انجام نشد',approve);log('APPROVED');
 const post=await req(`/api/iran/payroll/batches/${batch.id}/post`,{token,method:'POST',body:{}});assert(post.ok&&Number(post.debit)>0&&Math.abs(Number(post.debit)-Number(post.credit))<1,'سند حقوق متوازن نیست',post);log('POSTED',{debit:post.debit,credit:post.credit});
 const slips=await req(`/api/iran/payroll/batches/${batch.id}/slips`,{token});const slip=slips.find(x=>Number(x.employee_party_id)===Number(emp.partyId));assert(slip&&slip.status==='POSTED'&&Number(slip.net_pay)>0,'فیش حقوق نهایی پیدا نشد',slips);log('SLIP_OK',{net:slip.net_pay,insurance:slip.employee_insurance,tax:slip.salary_tax});
 const lines=await req(`/api/iran/payroll/slips/${slip.id}/lines`,{token});assert(lines.some(x=>x.line_code==='BASE')&&lines.some(x=>x.line_code==='EMP_INS'),'ریز فیش کامل نیست',lines);log('SLIP_LINES_OK',lines.length);
 const tb=await req('/api/finance/trial-balance',{token}),dr=tb.reduce((s,x)=>s+Number(x.debit||0),0),cr=tb.reduce((s,x)=>s+Number(x.credit||0),0);assert(Math.abs(dr-cr)<1,'تراز بعد از حقوق متوازن نیست',{dr,cr});log('TRIAL_BALANCE_OK',{dr,cr});
 log('PASS');
}
main().catch(e=>{console.error(`[PAYROLL-E2E][FAIL] ${e.message}`);if(e.data)console.error(JSON.stringify(e.data,null,2));process.exit(1)});
