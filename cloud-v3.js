import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.111.0/+esm';

const baseCfg = window.JPRO_CONFIG || {};
let cfg = {...baseCfg};
if (!cfg.SUPABASE_PUBLISHABLE_KEY && cfg.CONFIG_ENDPOINT) {
  try {
    const r = await fetch(cfg.CONFIG_ENDPOINT, {cache:'no-store'});
    if (!r.ok) throw new Error(`Config endpoint ${r.status}`);
    cfg = {...cfg, ...(await r.json())};
  } catch (err) {
    console.error('JPro config bootstrap failed', err);
  }
}

const hasConfig = Boolean(cfg.SUPABASE_URL && cfg.SUPABASE_PUBLISHABLE_KEY);
const supabase = hasConfig ? createClient(cfg.SUPABASE_URL, cfg.SUPABASE_PUBLISHABLE_KEY, {
  auth: { persistSession:true, autoRefreshToken:true, detectSessionInUrl:true }
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

let cloudUser = null;
let currentCompany = null;
let membership = null;
let realtimeChannel = null;
let hydrating = false;
let syncing = false;
const timers = new Map();

function msg(text,error=false){
  const el=$('authMessage'); if(!el) return;
  el.textContent=text; el.style.color=error?'#9b2c2c':'#2f6d49';
}
function setCloudState(v){ if($('cloudState')) $('cloudState').textContent=v; }
function showSyncBanner(text='اطلاعات جدید از سرور دریافت شد.'){
  const el=$('syncBanner'); if(!el) return;
  el.textContent=text; el.classList.remove('hidden'); setTimeout(()=>el.classList.add('hidden'),1800);
}
function configGuard(){
  if(hasConfig) return true;
  $('setupWarning')?.classList.remove('hidden');
  if($('setupWarning')) $('setupWarning').textContent='اتصال Supabase آماده نشد. اینترنت و Config Endpoint را بررسی کنید.';
  if($('loginBtn')) $('loginBtn').disabled=true;
  if($('signupBtn')) $('signupBtn').disabled=true;
  return false;
}
function escapeHtml(v=''){
  return String(v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}
function stableJson(v){ try{return JSON.stringify(v)}catch{return ''} }
function recordIdFor(item,index){ return String(item?.id || item?.code || item?.recordId || `row-${index}`); }
function clearSyncedLocalState(){ for(const key of SYNC_KEYS) localStorage.removeItem(key); }
function seedCloudCompanyContext(){
  if(!currentCompany) return;
  if(!localStorage.getItem('jpro_core_v3')){
    localStorage.setItem('jpro_core_v3',JSON.stringify({
      companies:[{id:currentCompany.id,name:currentCompany.name,active:true}],
      activeCompany:currentCompany.id
    }));
  }
}
async function sha256(text){
  const b=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(String(text)));
  return [...new Uint8Array(b)].map(x=>x.toString(16).padStart(2,'0')).join('');
}
async function auditEvent(companyId,action,recordType='',recordId='',details={}){
  if(!supabase||!cloudUser||!companyId) return;
  try{
    await supabase.from('audit_events').insert({
      company_id:companyId,user_id:cloudUser.id,action,
      record_type:recordType||null,record_id:recordId||null,details
    });
  }catch(err){ console.warn('audit',err); }
}

async function authLogin(){
  if(!configGuard()) return;
  msg('در حال ورود...');
  const {data,error}=await supabase.auth.signInWithPassword({email:$('email').value.trim(),password:$('password').value});
  if(error) return msg(error.message,true);
  await afterAuth(data.user);
}
async function authSignup(){
  if(!configGuard()) return;
  const email=$('email').value.trim(),password=$('password').value;
  if(!email||password.length<8) return msg('ایمیل و رمز حداقل ۸ کاراکتری لازم است.',true);
  msg('در حال ساخت حساب...');
  const {data,error}=await supabase.auth.signUp({email,password,options:{data:{source:'jpro-cloud'}}});
  if(error) return msg(error.message,true);
  if(data.session) await afterAuth(data.user);
  else msg('حساب ساخته شد. اگر تأیید ایمیل فعال باشد، ایمیل را تأیید و سپس وارد شوید.');
}
async function ensureProfile(user){
  const {error}=await supabase.from('profiles').upsert({
    id:user.id,email:user.email,
    full_name:user.user_metadata?.full_name || user.email?.split('@')[0] || 'کاربر JPro'
  },{onConflict:'id'});
  if(error) throw error;
}
async function loadMemberships(){
  const {data,error}=await supabase.from('company_memberships')
    .select('company_id,role,unit_id,active,companies(id,code,name,join_code,active)')
    .eq('user_id',cloudUser.id).eq('active',true);
  if(error) throw error;
  return (data||[]).filter(x=>x.companies?.active!==false);
}
async function afterAuth(user){
  cloudUser=user;
  try{
    await ensureProfile(user);
    const memberships=await loadMemberships();
    $('authPanel')?.classList.add('hidden');
    if(!memberships.length){
      $('companyPanel')?.classList.add('hidden');
      $('onboardPanel')?.classList.remove('hidden');
      return;
    }
    $('onboardPanel')?.classList.add('hidden');
    $('companyPanel')?.classList.remove('hidden');
    $('companySelect').innerHTML=memberships.map((m,i)=>`<option value="${m.company_id}" ${i===0?'selected':''}>${escapeHtml(m.companies.name)} — ${escapeHtml(m.role)}</option>`).join('');
    $('companySelect')._memberships=memberships;
  }catch(err){ msg(err.message,true); }
}
async function createCompany(){
  const name=$('newCompanyName').value.trim(),code=$('newCompanyCode').value.trim();
  if(!name||!code) return alert('نام و کد شرکت لازم است.');
  const {data:company,error}=await supabase.from('companies').insert({name,code,created_by:cloudUser.id}).select().single();
  if(error) return alert(error.message);
  const {error:memErr}=await supabase.from('company_memberships').insert({company_id:company.id,user_id:cloudUser.id,role:'admin',active:true});
  if(memErr) return alert(memErr.message);
  const units=[
    ['FIN','مالی و حسابداری'],['SAL','فروش'],['PUR','خرید'],['WH','انبار'],
    ['LOG','لجستیک'],['HR','منابع انسانی'],['MGT','مدیریت']
  ].map(([unitCode,unitName])=>({company_id:company.id,code:unitCode,name:unitName,active:true}));
  const {error:unitErr}=await supabase.from('units').insert(units);
  if(unitErr) console.warn('default units',unitErr);
  await auditEvent(company.id,'company.created','company',company.id,{name,code});
  $('onboardPanel')?.classList.add('hidden');
  await afterAuth(cloudUser);
}
async function requestJoinByCode(){
  const code=$('joinCode')?.value?.trim();
  if(!code) return alert('کد عضویت را وارد کنید.');
  const {error}=await supabase.rpc('request_company_join',{p_join_code:code,p_requested_role:'requester',p_note:'درخواست عضویت از JPro Cloud'});
  if(error){
    const m=error.message||'';
    return alert(m.includes('ALREADY_MEMBER')?'قبلاً عضو این شرکت هستید.':m.includes('JOIN_CODE_NOT_FOUND')?'کد عضویت معتبر نیست.':m);
  }
  alert('درخواست عضویت ثبت شد و باید توسط مدیر شرکت تأیید شود.');
}
async function openSelectedCompany(){
  const ms=$('companySelect')._memberships||[];
  membership=ms.find(x=>x.company_id===$('companySelect').value);
  if(!membership) return;
  currentCompany=membership.companies;
  clearSyncedLocalState();
  await hydrateCompany();
  seedCloudCompanyContext();
  await seedLegacySession();
  startRealtime();
  $('boot')?.classList.add('hidden');
  $('appShell')?.classList.remove('hidden');
  $('userLabel').textContent=cloudUser.email||'کاربر';
  $('companyLabel').textContent=currentCompany.name;
  $('jproFrame').src='./legacy.html';
  await auditEvent(currentCompany.id,'company.opened','company',currentCompany.id,{role:membership.role});
}
async function seedLegacySession(){
  const {data:p}=await supabase.from('profiles').select('*').eq('id',cloudUser.id).maybeSingle();
  const localUser={
    id:cloudUser.id,username:cloudUser.email,fullName:p?.full_name||cloudUser.email,
    title:p?.title||'کاربر JPro',unit:p?.unit_name||'',role:membership?.role||'finance',
    pinHash:await sha256('1234'),signatureImage:'',active:true,cloud:true,createdAt:new Date().toISOString()
  };
  localStorage.setItem(LOCAL_USER_KEY,JSON.stringify([localUser]));
  localStorage.setItem(LOCAL_SESSION_KEY,JSON.stringify({userId:localUser.id,loginAt:new Date().toISOString(),cloud:true,companyId:currentCompany.id}));
}

async function fetchServerRows(key){
  const {data,error}=await supabase.from('erp_records')
    .select('record_id,payload,revision,updated_at,deleted_at')
    .eq('company_id',currentCompany.id).eq('record_type',key);
  if(error) throw error;
  return data||[];
}
async function hydrateCompany(){
  if(!currentCompany) return;
  hydrating=true;
  try{
    const {data,error}=await supabase.from('erp_records')
      .select('record_type,record_id,payload,revision,updated_at,deleted_at')
      .eq('company_id',currentCompany.id);
    if(error) throw error;
    const grouped=new Map();
    for(const row of (data||[])){
      if(!grouped.has(row.record_type)) grouped.set(row.record_type,[]);
      grouped.get(row.record_type).push(row);
    }
    for(const key of ARRAY_KEYS){
      const rows=grouped.get(key)||[];
      if(!rows.length) continue;
      const live=rows.filter(r=>!r.deleted_at).map(r=>r.payload);
      localStorage.setItem(key,JSON.stringify(live));
    }
    for(const key of SINGLETON_KEYS){
      const rows=grouped.get(key)||[];
      if(!rows.length) continue;
      const live=rows.find(r=>r.record_id==='singleton'&&!r.deleted_at)?.payload;
      if(live&&typeof live==='object') localStorage.setItem(key,JSON.stringify(live));
      else localStorage.removeItem(key);
    }
  }finally{ hydrating=false; }
}
async function rpcSave(key,id,payload,expectedRevision){
  const {data,error}=await supabase.rpc('jpro_save_record',{
    p_company:currentCompany.id,p_record_type:key,p_record_id:String(id),p_payload:payload,p_expected_revision:expectedRevision
  });
  if(error) throw error;
  return data?.[0]||null;
}
async function rpcDelete(key,id,expectedRevision){
  const {data,error}=await supabase.rpc('jpro_delete_record',{
    p_company:currentCompany.id,p_record_type:key,p_record_id:String(id),p_expected_revision:expectedRevision
  });
  if(error) throw error;
  return data?.[0]||null;
}
async function syncArrayKey(key,value){
  const arr=Array.isArray(value)?value:[];
  const server=await fetchServerRows(key);
  const serverMap=new Map(server.map(r=>[String(r.record_id),r]));
  const localIds=new Set();

  for(let i=0;i<arr.length;i++){
    const item=arr[i],id=recordIdFor(item,i); localIds.add(id);
    const old=serverMap.get(id);
    if(old&&!old.deleted_at&&stableJson(old.payload)===stableJson(item)) continue;
    await rpcSave(key,id,item,old?.revision??0);
  }
  for(const row of server){
    const id=String(row.record_id);
    if(!row.deleted_at&&!localIds.has(id)) await rpcDelete(key,id,row.revision);
  }
}
async function syncSingletonKey(key,value){
  const server=await fetchServerRows(key);
  const old=server.find(r=>r.record_id==='singleton');
  if(value&&typeof value==='object'){
    if(old&&!old.deleted_at&&stableJson(old.payload)===stableJson(value)) return;
    await rpcSave(key,'singleton',value,old?.revision??0);
  }else if(old&&!old.deleted_at){
    await rpcDelete(key,'singleton',old.revision);
  }
}
async function syncKey(key,raw,{quiet=true}={}){
  if(!supabase||!currentCompany||hydrating||!SYNC_KEYS.has(key)) return;
  let value;
  try{ value=raw==null?(ARRAY_KEYS.has(key)?[]:null):JSON.parse(raw); }catch{return;}
  try{
    syncing=true;
    if(ARRAY_KEYS.has(key)) await syncArrayKey(key,value);
    else await syncSingletonKey(key,value);
    setCloudState('همگام');
  }catch(err){
    console.error('syncKey',key,err);
    const conflict=String(err?.message||'').includes('JPRO_REVISION_CONFLICT') || err?.code==='40001';
    setCloudState(conflict?'تعارض Sync':'خطای Sync');
    if(conflict){
      await hydrateCompany();
      const frame=$('jproFrame');
      if(frame?.contentWindow) frame.contentWindow.postMessage({type:'jpro-cloud-refresh'},window.location.origin);
      if(!quiet) alert('همزمان کاربر دیگری این اطلاعات را تغییر داده است. آخرین نسخه سرور بارگذاری شد؛ تغییر را دوباره بررسی کن.');
    }else if(!quiet){
      alert(err?.message||'خطای همگام‌سازی');
    }
  }finally{ syncing=false; }
}
function queueSync(key,value){
  clearTimeout(timers.get(key));
  timers.set(key,setTimeout(()=>syncKey(key,value,{quiet:true}),650));
}
window.addEventListener('storage',(e)=>{
  if(e.storageArea===localStorage&&SYNC_KEYS.has(e.key)&&!hydrating) queueSync(e.key,e.newValue);
});
function startRealtime(){
  if(realtimeChannel) supabase.removeChannel(realtimeChannel);
  realtimeChannel=supabase.channel(`jpro-${currentCompany.id}`)
    .on('postgres_changes',{event:'*',schema:'public',table:'erp_records',filter:`company_id=eq.${currentCompany.id}`},async(payload)=>{
      const by=payload.new?.updated_by||payload.old?.updated_by;
      if(by===cloudUser.id||syncing) return;
      await hydrateCompany();
      showSyncBanner();
      const frame=$('jproFrame');
      if(frame?.contentWindow) frame.contentWindow.postMessage({type:'jpro-cloud-refresh'},window.location.origin);
    }).subscribe((status)=>setCloudState(status==='SUBSCRIBED'?'متصل':'در حال اتصال...'));
}

async function uploadAttachment(recordType,recordId,file){
  if(!currentCompany||!file) throw new Error('Company/file missing');
  const safe=(file.name||'file').replace(/[^\p{L}\p{N}._-]+/gu,'_');
  const path=`${currentCompany.id}/${recordType}/${recordId}/${crypto.randomUUID()}-${safe}`;
  const {error:upErr}=await supabase.storage.from('jpro-private').upload(path,file,{upsert:false,contentType:file.type||undefined});
  if(upErr) throw upErr;
  const {data,error}=await supabase.from('attachments').insert({
    company_id:currentCompany.id,record_type:recordType,record_id:String(recordId),
    object_path:path,original_name:file.name||safe,mime_type:file.type||null,
    size_bytes:file.size||null,uploaded_by:cloudUser.id
  }).select().single();
  if(error){ await supabase.storage.from('jpro-private').remove([path]); throw error; }
  await auditEvent(currentCompany.id,'attachment.uploaded',recordType,String(recordId),{attachment_id:data.id,name:data.original_name});
  return data;
}
async function listAttachments(recordType,recordId){
  const {data,error}=await supabase.from('attachments').select('*')
    .eq('company_id',currentCompany.id).eq('record_type',recordType).eq('record_id',String(recordId))
    .order('created_at',{ascending:false});
  if(error) throw error; return data||[];
}
async function downloadAttachment(attachment){
  const {data,error}=await supabase.storage.from(attachment.bucket_id||'jpro-private').download(attachment.object_path);
  if(error) throw error; return data;
}
async function signedAttachmentUrl(attachment,expiresIn=300){
  const {data,error}=await supabase.storage.from(attachment.bucket_id||'jpro-private').createSignedUrl(attachment.object_path,expiresIn);
  if(error) throw error; return data?.signedUrl||'';
}
async function deleteAttachment(attachment){
  const {error:sErr}=await supabase.storage.from(attachment.bucket_id||'jpro-private').remove([attachment.object_path]);
  if(sErr) throw sErr;
  const {error}=await supabase.from('attachments').delete().eq('id',attachment.id);
  if(error) throw error;
  await auditEvent(currentCompany.id,'attachment.deleted',attachment.record_type,attachment.record_id,{attachment_id:attachment.id});
}

async function manualSync(){
  if(!currentCompany) return;
  setCloudState('در حال Sync...');
  for(const key of SYNC_KEYS) await syncKey(key,localStorage.getItem(key),{quiet:false});
  await hydrateCompany();
  const frame=$('jproFrame');
  if(frame?.contentWindow) frame.contentWindow.postMessage({type:'jpro-cloud-refresh'},window.location.origin);
  setCloudState('همگام');
  showSyncBanner('همگام‌سازی کامل شد.');
}
async function logout(){
  if(currentCompany) await auditEvent(currentCompany.id,'auth.logout');
  if(realtimeChannel) await supabase.removeChannel(realtimeChannel);
  await supabase.auth.signOut();
  clearSyncedLocalState();
  localStorage.removeItem(LOCAL_SESSION_KEY);
  location.reload();
}
async function verifyCloudSignature(){
  const password=prompt('برای تأیید امضای الکترونیکی، رمز حساب JPro Cloud را مجدداً وارد کنید:');
  if(password===null) return false;
  const {error}=await supabase.auth.signInWithPassword({email:cloudUser.email,password});
  if(error){ alert('رمز صحیح نیست. امضا انجام نشد.'); return false; }
  if(currentCompany) await auditEvent(currentCompany.id,'signature.reauth');
  return true;
}

window.JPRO_CLOUD={
  verifySignature:verifyCloudSignature,manualSync,
  uploadAttachment,listAttachments,downloadAttachment,signedAttachmentUrl,deleteAttachment,
  get companyId(){return currentCompany?.id||null},
  get userId(){return cloudUser?.id||null}
};

$('loginBtn')?.addEventListener('click',authLogin);
$('signupBtn')?.addEventListener('click',authSignup);
$('openCompanyBtn')?.addEventListener('click',openSelectedCompany);
$('createCompanyBtn')?.addEventListener('click',createCompany);
$('joinBtn')?.addEventListener('click',requestJoinByCode);
$('syncBtn')?.addEventListener('click',manualSync);
$('logoutBtn')?.addEventListener('click',logout);
$('cloudToggle')?.addEventListener('click',()=>$('cloudPanel')?.classList.toggle('hidden'));
$('cloudClose')?.addEventListener('click',()=>$('cloudPanel')?.classList.add('hidden'));

configGuard();
if(supabase){
  const {data:{session}}=await supabase.auth.getSession();
  if(session?.user) await afterAuth(session.user);
}
