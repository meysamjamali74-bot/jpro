import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.111.0/+esm';

const cfg = window.JPRO_CONFIG || {};
const hasConfig = Boolean(cfg.SUPABASE_URL && cfg.SUPABASE_PUBLISHABLE_KEY);
const supabase = hasConfig ? createClient(cfg.SUPABASE_URL, cfg.SUPABASE_PUBLISHABLE_KEY, {
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
}) : null;

const $ = (id) => document.getElementById(id);
const ARRAY_KEYS = new Set([
  'erp_docs_v3','erp_payments_v3','erp_logs_v3',
  'jpro_parties_v1','jpro_products_v1','jpro_sales_v1',
  'jpro_coa_v3','jpro_warehouses_v3','jpro_rules_v3',
  'jpro_coord_v5','jpro_person_categories_v5','jpro_product_categories_v5',
  'jpro_approval_templates_v5'
]);
const SINGLETON_KEYS = new Set([
  'jpro_core_v3','jpro_settings_v2','jpro_permissions_v2',
  'jpro_definitions_v4','jpro_org_v5','jpro_access_scopes_v5'
]);
const SYNC_KEYS = new Set([...ARRAY_KEYS, ...SINGLETON_KEYS]);
const LOCAL_USER_KEY = 'erp_users_v3';
const LOCAL_SESSION_KEY = 'erp_session_v3';
let cloudUser = null, currentCompany = null, membership = null, realtimeChannel = null, hydrating = false;
const timers = new Map();

function msg(text, error=false){ $('authMessage').textContent=text; $('authMessage').style.color=error?'#9b2c2c':'#2f6d49'; }
function configGuard(){
  if(hasConfig) return true;
  $('setupWarning').classList.remove('hidden');
  $('setupWarning').textContent='پروژه Supabase هنوز به این نسخه متصل نشده است. فایل config.js باید با Project URL و Publishable Key پر شود.';
  $('loginBtn').disabled = $('signupBtn').disabled = true;
  return false;
}
async function sha256(text){
  const b=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(String(text)));
  return [...new Uint8Array(b)].map(x=>x.toString(16).padStart(2,'0')).join('');
}
async function authLogin(){
  if(!configGuard()) return; msg('در حال ورود...');
  const {data,error}=await supabase.auth.signInWithPassword({email:$('email').value.trim(),password:$('password').value});
  if(error) return msg(error.message,true); await afterAuth(data.user);
}
async function authSignup(){
  if(!configGuard()) return;
  const email=$('email').value.trim(), password=$('password').value;
  if(!email||password.length<8) return msg('ایمیل و رمز حداقل ۸ کاراکتری لازم است.',true);
  msg('در حال ساخت حساب...');
  const {data,error}=await supabase.auth.signUp({email,password,options:{data:{source:'jpro-cloud'}}});
  if(error) return msg(error.message,true);
  if(data.session) await afterAuth(data.user); else msg('حساب ساخته شد. اگر تأیید ایمیل فعال باشد، ایمیل خود را تأیید و سپس وارد شوید.');
}
async function ensureProfile(user){
  const {error}=await supabase.from('profiles').upsert({id:user.id,email:user.email,full_name:user.user_metadata?.full_name || user.email?.split('@')[0] || 'کاربر JPro'},{onConflict:'id'});
  if(error) throw error;
}
async function loadMemberships(){
  const {data,error}=await supabase.from('company_memberships').select('company_id,role,unit_id,active,companies(id,code,name,active)').eq('user_id',cloudUser.id).eq('active',true);
  if(error) throw error; return (data||[]).filter(x=>x.companies?.active!==false);
}
async function afterAuth(user){
  cloudUser=user;
  try{
    await ensureProfile(user); const memberships=await loadMemberships(); $('authPanel').classList.add('hidden');
    if(!memberships.length){ $('onboardPanel').classList.remove('hidden'); return; }
    $('companyPanel').classList.remove('hidden');
    $('companySelect').innerHTML=memberships.map((m,i)=>`<option value="${m.company_id}" ${i===0?'selected':''}>${escapeHtml(m.companies.name)} — ${escapeHtml(m.role)}</option>`).join('');
    $('companySelect')._memberships=memberships;
  }catch(err){msg(err.message,true)}
}
async function createCompany(){
  const name=$('newCompanyName').value.trim(),code=$('newCompanyCode').value.trim(); if(!name||!code) return alert('نام و کد شرکت لازم است.');
  const {data:company,error}=await supabase.from('companies').insert({name,code,created_by:cloudUser.id}).select().single(); if(error) return alert(error.message);
  const {error:memErr}=await supabase.from('company_memberships').insert({company_id:company.id,user_id:cloudUser.id,role:'admin',active:true}); if(memErr) return alert(memErr.message);
  const units=[['FIN','مالی و حسابداری'],['SAL','فروش'],['WH','انبار'],['LOG','لجستیک'],['MGT','مدیریت']].map(([code,name])=>({company_id:company.id,code,name,active:true}));
  await supabase.from('units').insert(units); $('onboardPanel').classList.add('hidden'); await afterAuth(cloudUser);
}
async function openSelectedCompany(){
  const ms=$('companySelect')._memberships||[]; membership=ms.find(x=>x.company_id===$('companySelect').value); if(!membership) return;
  currentCompany=membership.companies; await hydrateCompany(); await seedLegacySession(); startRealtime();
  $('boot').classList.add('hidden'); $('appShell').classList.remove('hidden'); $('userLabel').textContent=cloudUser.email||'کاربر'; $('companyLabel').textContent=currentCompany.name; $('jproFrame').src='./legacy.html';
}
async function seedLegacySession(){
  const {data:p}=await supabase.from('profiles').select('*').eq('id',cloudUser.id).maybeSingle();
  const localUser={id:cloudUser.id,username:cloudUser.email,fullName:p?.full_name||cloudUser.email,title:p?.title||'کاربر JPro',unit:p?.unit_name||'',role:membership?.role||'finance',pinHash:await sha256('1234'),signatureImage:'',active:true,cloud:true,createdAt:new Date().toISOString()};
  localStorage.setItem(LOCAL_USER_KEY,JSON.stringify([localUser])); localStorage.setItem(LOCAL_SESSION_KEY,JSON.stringify({userId:localUser.id,loginAt:new Date().toISOString(),cloud:true}));
}
function recordIdFor(item,index){ return String(item?.id || item?.code || item?.recordId || `row-${index}`); }
async function hydrateCompany(){
  hydrating=true;
  try{
    const {data,error}=await supabase.from('erp_records').select('record_type,record_id,payload,updated_at').eq('company_id',currentCompany.id).is('deleted_at',null); if(error) throw error;
    const grouped=new Map(); for(const row of (data||[])){ if(!grouped.has(row.record_type)) grouped.set(row.record_type,[]); grouped.get(row.record_type).push(row); }
    for(const key of SYNC_KEYS){ const rows=grouped.get(key)||[]; if(ARRAY_KEYS.has(key)){ const arr=rows.map(r=>r.payload); if(arr.length) localStorage.setItem(key,JSON.stringify(arr)); } else { const single=rows.find(r=>r.record_id==='singleton')?.payload; if(single&&typeof single==='object') localStorage.setItem(key,JSON.stringify(single)); } }
  }finally{ hydrating=false; }
}
async function syncKey(key,raw){
  if(!supabase||!currentCompany||hydrating||!SYNC_KEYS.has(key)||!raw) return;
  let value; try{value=JSON.parse(raw)}catch{return}
  try{
    if(ARRAY_KEYS.has(key)){
      const arr=Array.isArray(value)?value:[]; const rows=arr.map((item,i)=>({company_id:currentCompany.id,record_type:key,record_id:recordIdFor(item,i),payload:item,updated_by:cloudUser.id,updated_at:new Date().toISOString(),deleted_at:null}));
      if(rows.length){ const {error}=await supabase.from('erp_records').upsert(rows,{onConflict:'company_id,record_type,record_id'}); if(error) throw error; }
    }else{
      const {error}=await supabase.from('erp_records').upsert({company_id:currentCompany.id,record_type:key,record_id:'singleton',payload:value,updated_by:cloudUser.id,updated_at:new Date().toISOString(),deleted_at:null},{onConflict:'company_id,record_type,record_id'}); if(error) throw error;
    }
    setCloudState('همگام');
  }catch(err){console.error('syncKey',key,err);setCloudState('خطای Sync')}
}
function queueSync(key,value){clearTimeout(timers.get(key));timers.set(key,setTimeout(()=>syncKey(key,value),450))}
window.addEventListener('storage',(e)=>{if(e.storageArea===localStorage&&SYNC_KEYS.has(e.key))queueSync(e.key,e.newValue)});
function startRealtime(){
  if(realtimeChannel) supabase.removeChannel(realtimeChannel);
  realtimeChannel=supabase.channel(`jpro-${currentCompany.id}`).on('postgres_changes',{event:'*',schema:'public',table:'erp_records',filter:`company_id=eq.${currentCompany.id}`},async(payload)=>{
    if(payload.new?.updated_by===cloudUser.id)return; await hydrateCompany(); showSyncBanner(); const frame=$('jproFrame'); if(frame?.contentWindow)frame.contentWindow.postMessage({type:'jpro-cloud-refresh'},window.location.origin);
  }).subscribe();
}
function showSyncBanner(){$('syncBanner').classList.remove('hidden');setTimeout(()=>$('syncBanner').classList.add('hidden'),1800)}
function setCloudState(v){$('cloudState').textContent=v}
async function manualSync(){setCloudState('در حال Sync...');for(const key of SYNC_KEYS){const raw=localStorage.getItem(key);if(raw)await syncKey(key,raw)}await hydrateCompany();const frame=$('jproFrame');if(frame?.contentWindow)frame.contentWindow.postMessage({type:'jpro-cloud-refresh'},window.location.origin);setCloudState('همگام')}
async function logout(){await supabase.auth.signOut();localStorage.removeItem(LOCAL_SESSION_KEY);location.reload()}
async function verifyCloudSignature(){const password=prompt('برای تأیید امضای الکترونیکی، رمز حساب JPro Cloud را مجدداً وارد کنید:');if(password===null)return false;const {error}=await supabase.auth.signInWithPassword({email:cloudUser.email,password});if(error){alert('رمز صحیح نیست. امضا انجام نشد.');return false}return true}
function escapeHtml(v=''){return String(v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
window.JPRO_CLOUD={verifySignature:verifyCloudSignature,manualSync};
$('loginBtn').onclick=authLogin;$('signupBtn').onclick=authSignup;$('openCompanyBtn').onclick=openSelectedCompany;$('createCompanyBtn').onclick=createCompany;$('syncBtn').onclick=manualSync;$('logoutBtn').onclick=logout;$('cloudToggle').onclick=()=>$('cloudPanel').classList.toggle('hidden');$('cloudClose').onclick=()=>$('cloudPanel').classList.add('hidden');
configGuard();if(supabase){const {data:{session}}=await supabase.auth.getSession();if(session?.user)await afterAuth(session.user)}
