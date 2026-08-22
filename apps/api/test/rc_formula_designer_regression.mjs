import assert from 'node:assert/strict';
const base=process.env.TEST_BASE_URL||'http://127.0.0.1:8080';
async function api(path,{token,method='GET',body,allow=[]}={}){const r=await fetch(base+path,{method,headers:{'content-type':'application/json',...(token?{authorization:`Bearer ${token}`}:{})},body:body===undefined?undefined:JSON.stringify(body)}),text=await r.text();let data;try{data=JSON.parse(text)}catch{data=text}if(!r.ok&&!allow.includes(r.status))throw new Error(`${method} ${path} -> ${r.status}: ${typeof data==='string'?data:JSON.stringify(data)}`);return{status:r.status,data}}
async function login(email,password){return(await api('/api/auth/login',{method:'POST',body:{email,password}})).data.token}
const token=await login('p17-fin1@tarazpad.test','Strong_P17_Fin1_2026!');
const templates=(await api('/api/iran/finance/statement-templates',{token})).data;
let custom=templates.find(x=>x.code==='P17_PL_CUSTOM');
if(!custom){const std=templates.find(x=>x.code==='STD_PL');assert.ok(std);custom=(await api(`/api/iran/finance/statement-templates/${std.id}/clone`,{token,method:'POST',body:{code:'P17_PL_CUSTOM',title:'سود و زیان مدیریتی تست'}})).data}
const valid=(await api(`/api/iran/finance/statement-templates/${custom.id}/lines`,{token,method:'POST',body:{lineCode:'SAFE_RATIO',title:'نسبت فرمولی کنترل',lineType:'FORMULA',normalSign:'AUTO',formulaText:'OPERATING_REVENUE/(OPERATING_REVENUE-COST_OF_SALES)',sortOrder:200,displayLevel:1,isBold:false}}));
assert.equal(valid.status,201,'a structurally valid formula must not be rejected due to dummy-value divide by zero');
const a=(await api(`/api/iran/finance/statement-templates/${custom.id}/lines`,{token,method:'POST',body:{lineCode:'CYCLE_A',title:'کنترل چرخه الف',lineType:'ACCOUNT_SUM',normalSign:'AUTO',sortOrder:210}})).data;
const b=(await api(`/api/iran/finance/statement-templates/${custom.id}/lines`,{token,method:'POST',body:{lineCode:'CYCLE_B',title:'کنترل چرخه ب',lineType:'FORMULA',normalSign:'AUTO',formulaText:'CYCLE_A+1',sortOrder:220}})).data;
const cycle=await api(`/api/iran/finance/statement-lines/${a.id}`,{token,method:'PUT',body:{lineCode:'CYCLE_A',title:'کنترل چرخه الف',lineType:'FORMULA',normalSign:'AUTO',formulaText:'CYCLE_B+1'},allow:[422]});
assert.equal(cycle.status,422,'formula cycle A -> B -> A must be rejected');
assert.match(JSON.stringify(cycle.data),/چرخه/);
console.log('RC_FORMULA_DESIGNER_PASS');
