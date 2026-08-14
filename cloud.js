import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.111.0/+esm';

const cfg = window.JPRO_CONFIG || {};
let configuredUrl = cfg.SUPABASE_URL || localStorage.getItem('jpro_supabase_url') || '';
let configuredKey = cfg.SUPABASE_PUBLISHABLE_KEY || localStorage.getItem('jpro_supabase_publishable_key') || '';
let supabase = null;

async function initSupabase(){
  if((!configuredUrl || !configuredKey) && cfg.CONFIG_ENDPOINT){
    try{
      const res=await fetch(cfg.CONFIG_ENDPOINT,{cache:'no-store'});
      if(res.ok){
        const remote=await res.json();
        configuredUrl=configuredUrl || remote.SUPABASE_URL || '';
        configuredKey=configuredKey || remote.SUPABASE_PUBLISHABLE_KEY || '';
      }
    }catch(err){ console.warn('JPro public config endpoint unavailable',err); }
  }
  if(configuredUrl && configuredKey){
    supabase=createClient(configuredUrl,configuredKey,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
    return true;
  }
  return false;
}

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
const STORAGE_BUCKET = 'jpro-private';

let cloudUser = null;
let currentCompany = null;
let membership = null;
let realtimeChannel = null;
let hydrating = false;
const timers = new Map();
const revisionCache = new Map();

const recKey = (type,id) => `${type}::${id}`;
function msg(text, error=false){ if(!$('authMessage')) return; $('authMessage').textContent=text; $('authMessage').style.color=error?'#9b2c2c':'#2f6d49'; }
function setCloudState(v){ if($('cloudState')) $('cloudState').textContent=v; }

function configGuard(){
  if(supabase) return true;
  const box=$('setupWarning');
  if(box){
    box.classList.remove('hidden');
    box.innerHTML=`اتصال Supabase نیاز به Publishable Key دارد. این کلید عمومی است و فقط در مرورگر شما ذخیره می‌شود.<div style="display:flex;gap:6px;margin-top:8px"><input id="runtimePubKey" type="text" placeholder="sb_publishable_..." style="flex:1"><button id="saveRuntimeKey" type="button">ذخیره اتصال</button></div>`;
    setTimeout(()=>{
      const b=$('saveRuntimeKey');
      if(b) b.onclick=()=>{
        const key=$('runtimePubKey')?.value.trim();
        if(!configuredUrl) return alert('Project URL در config.js تنظیم نشده است.');
        if(!key) return alert('Publishable Key را وارد کن.');
        localStorage.setItem('jpro_supabase_url',configuredUrl);
        localStorage.setItem('jpro_supabase_publishable_key',key);
        location.reload();
      };
    },0);
  }
  if($('loginBtn')) $('loginBtn').disabled=true;
  if($('signupBtn')) $('signupBtn').disabled=true;
  return false;
}

async function sha256(text){
  const b=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(String(text)));
  return [...new Uint8Array(b)].map(x=>x.toString(16).padStart(2,'0')).join('');
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
  const email=$('email').value.trim(), password=$('password').value;
  if(!email||password.length<8) return msg('ایمیل و رمز حداقل ۸ کاراکتری لازم است.',true);
  msg('در حال ساخت حساب...');
  const {data,error}=await supabase.auth.signUp({email,password,options:{data:{source:'jpro-cloud'}}});
  if(error) return msg(error.message,true);
  if(data.session) await afterAuth(data.user);
  else msg('حساب ساخته شد. اگر تأیید ایمیل فعال باشد، ایمیل خود را تأیید و سپس وارد شوید.');
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
    .select('company_id,role,unit_id,active,permissions,companies(id,code,name,active)')
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
    if(!memberships.length){ $('onboardPanel')?.classList.remove('hidden'); return; }
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
  const units=[['FIN','مالی و حسابداری'],['SAL','فروش'],['PUR','خرید و تدارکات'],['WH','انبار'],['LOG','لجستیک'],['HR','منابع انسانی'],['MGT','مدیریت']]
    .map(([code,name])=>({company_id:company.id,code,name,active:true}));
  const {error:unitErr}=await supabase.from('units').insert(units);
  if(unitErr) console.warn('default units',unitErr);
  $('onboardPanel')?.classList.add('hidden');
  await afterAuth(cloudUser);
}
async function openSelectedCompany(){
  const ms=$('companySelect')._memberships||[];
  membership=ms.find(x=>x.company_id===$('companySelect').value);
  if(!membership) return;
  currentCompany=membership.companies;
  revisionCache.clear();
  await hydrateCompany();
  await seedLegacySession();
  startRealtime();
  $('boot')?.classList.add('hidden');
  $('appShell')?.classList.remove('hidden');
  $('userLabel').textContent=cloudUser.email||'کاربر';
  $('companyLabel').textContent=currentCompany.name;
  $('jproFrame').src='./legacy.html';
}
async function seedLegacySession(){
  const {data:p}=await supabase.from('profiles').select('*').eq('id',cloudUser.id).maybeSingle();
  const localUser={
    id:cloudUser.id,username:cloudUser.email,fullName:p?.full_name||cloudUser.email,
    title:p?.title||'کاربر JPro',unit:p?.unit_name||'',role:membership?.role||'finance',
    pinHash:await sha256('1234'),signatureImage:'',active:true,cloud:true,createdAt:new Date().toISOString()
  };
  localStorage.setItem(LOCAL_USER_KEY,JSON.stringify([localUser]));
  localStorage.setItem(LOCAL_SESSION_KEY,JSON.stringify({userId:localUser.id,loginAt:new Date().toISOString(),cloud:true}));
}
function recordIdFor(item,index){ return String(item?.id || item?.code || item?.recordId || `row-${index}`); }

async function hydrateCompany(){
  if(!currentCompany) return;
  hydrating=true;
  try{
    const {data,error}=await supabase.from('erp_records')
      .select('record_type,record_id,payload,revision,updated_at,deleted_at')
      .eq('company_id',currentCompany.id).is('deleted_at',null);
    if(error) throw error;
    const grouped=new Map();
    revisionCache.clear();
    for(const row of (data||[])){
      if(!grouped.has(row.record_type)) grouped.set(row.record_type,[]);
      grouped.get(row.record_type).push(row);
      revisionCache.set(recKey(row.record_type,row.record_id),Number(row.revision||0));
    }
    for(const key of SYNC_KEYS){
      const rows=grouped.get(key)||[];
      if(ARRAY_KEYS.has(key)){
        localStorage.setItem(key,JSON.stringify(rows.map(r=>r.payload)));
      }else{
        const single=rows.find(r=>r.record_id==='singleton')?.payload;
        if(single && typeof single==='object') localStorage.setItem(key,JSON.stringify(single));
        else localStorage.removeItem(key);
      }
    }
  }finally{ hydrating=false; }
}

async function rpcSave(type,id,payload,expected=null){
  const {data,error}=await supabase.rpc('jpro_save_record',{
    p_company:currentCompany.id,p_record_type:type,p_record_id:id,p_payload:payload,
    p_expected_revision:expected
  });
  if(error) throw error;
  const rev=Number(data?.[0]?.revision||0);
  revisionCache.set(recKey(type,id),rev);
  return rev;
}
async function rpcDelete(type,id,expected=null){
  const {data,error}=await supabase.rpc('jpro_delete_record',{
    p_company:currentCompany.id,p_record_type:type,p_record_id:id,p_expected_revision:expected
  });
  if(error) throw error;
  revisionCache.delete(recKey(type,id));
  return Number(data?.[0]?.revision||0);
}
async function syncKey(key,raw){
  if(!supabase||!currentCompany||hydrating||!SYNC_KEYS.has(key)) return;
  let value;
  try{ value=raw===null ? (ARRAY_KEYS.has(key)?[]:null) : JSON.parse(raw); }catch{return;}
  try{
    if(ARRAY_KEYS.has(key)){
      const arr=Array.isArray(value)?value:[];
      const desired=new Map(arr.map((item,i)=>[recordIdFor(item,i),item]));
      const {data:serverRows,error:readErr}=await supabase.from('erp_records')
        .select('record_id,revision').eq('company_id',currentCompany.id).eq('record_type',key).is('deleted_at',null);
      if(readErr) throw readErr;
      const server=new Map((serverRows||[]).map(r=>[r.record_id,Number(r.revision||0)]));

      for(const [id,item] of desired){
        const expected=server.has(id)?server.get(id):(revisionCache.get(recKey(key,id))??0);
        await rpcSave(key,id,item,expected);
      }
      for(const [id,revision] of server){
        if(!desired.has(id)) await rpcDelete(key,id,revision);
      }
    }else{
      if(value===null){
        const expected=revisionCache.get(recKey(key,'singleton'));
        if(expected!=null) await rpcDelete(key,'singleton',expected);
      }else{
        const expected=revisionCache.get(recKey(key,'singleton'))??0;
        await rpcSave(key,'singleton',value,expected);
      }
    }
    setCloudState('همگام');
  }catch(err){
    console.error('syncKey',key,err);
    if(String(err?.message||'').includes('JPRO_REVISION_CONFLICT')){
      setCloudState('تداخل تغییرات');
      await hydrateCompany();
      alert('این اطلاعات همزمان توسط کاربر دیگری تغییر کرده بود. آخرین نسخه سرور دریافت شد؛ تغییر خودت را دوباره بررسی و ثبت کن.');
      $('jproFrame')?.contentWindow?.postMessage({type:'jpro-cloud-refresh'},window.location.origin);
    }else setCloudState('خطای Sync');
  }
}
function queueSync(key,value){
  clearTimeout(timers.get(key));
  timers.set(key,setTimeout(()=>syncKey(key,value),500));
}
window.addEventListener('storage',(e)=>{
  if(e.storageArea===localStorage&&SYNC_KEYS.has(e.key)) queueSync(e.key,e.newValue);
});

function startRealtime(){
  if(realtimeChannel) supabase.removeChannel(realtimeChannel);
  realtimeChannel=supabase.channel(`jpro-${currentCompany.id}`)
    .on('postgres_changes',{event:'*',schema:'public',table:'erp_records',filter:`company_id=eq.${currentCompany.id}`},async(payload)=>{
      const actor=payload.new?.updated_by || payload.old?.updated_by;
      if(actor===cloudUser.id) return;
      await hydrateCompany();
      showSyncBanner();
      $('jproFrame')?.contentWindow?.postMessage({type:'jpro-cloud-refresh'},window.location.origin);
    }).subscribe(status=>setCloudState(status==='SUBSCRIBED'?'Realtime متصل':'در حال اتصال'));
}
function showSyncBanner(){ $('syncBanner')?.classList.remove('hidden'); setTimeout(()=>$('syncBanner')?.classList.add('hidden'),1800); }
async function manualSync(){
  setCloudState('در حال Sync...');
  for(const key of SYNC_KEYS) await syncKey(key,localStorage.getItem(key));
  await hydrateCompany();
  $('jproFrame')?.contentWindow?.postMessage({type:'jpro-cloud-refresh'},window.location.origin);
  setCloudState('همگام');
}

async function uploadAttachment(file,recordType,recordId){
  if(!file||!currentCompany) throw new Error('فایل یا شرکت فعال موجود نیست.');
  const safe=(file.name||'file').replace(/[^\p{L}\p{N}._-]+/gu,'_');
  const path=`${currentCompany.id}/${recordType}/${recordId}/${crypto.randomUUID()}-${safe}`;
  const {error:upErr}=await supabase.storage.from(STORAGE_BUCKET).upload(path,file,{upsert:false,contentType:file.type||undefined});
  if(upErr) throw upErr;
  const {data,error}=await supabase.from('attachments').insert({
    company_id:currentCompany.id,record_type:recordType,record_id:String(recordId),bucket_id:STORAGE_BUCKET,
    object_path:path,original_name:file.name,mime_type:file.type||null,size_bytes:file.size,uploaded_by:cloudUser.id
  }).select().single();
  if(error){ await supabase.storage.from(STORAGE_BUCKET).remove([path]); throw error; }
  return data;
}
async function listAttachments(recordType,recordId){
  const {data,error}=await supabase.from('attachments').select('*').eq('company_id',currentCompany.id).eq('record_type',recordType).eq('record_id',String(recordId)).order('created_at',{ascending:false});
  if(error) throw error; return data||[];
}
async function downloadAttachment(att){
  const {data,error}=await supabase.storage.from(STORAGE_BUCKET).download(att.object_path);if(error)throw error;
  const url=URL.createObjectURL(data),a=document.createElement('a');a.href=url;a.download=att.original_name||'attachment';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
}
async function deleteAttachment(att){
  const {error:sErr}=await supabase.storage.from(STORAGE_BUCKET).remove([att.object_path]);if(sErr)throw sErr;
  const {error}=await supabase.from('attachments').delete().eq('id',att.id);if(error)throw error;
}

async function logout(){ await supabase.auth.signOut(); localStorage.removeItem(LOCAL_SESSION_KEY); location.reload(); }
async function verifyCloudSignature(){
  const password=prompt('برای تأیید امضای الکترونیکی، رمز حساب JPro Cloud را مجدداً وارد کنید:');
  if(password===null)return false;
  const {error}=await supabase.auth.signInWithPassword({email:cloudUser.email,password});
  if(error){alert('رمز صحیح نیست. امضا انجام نشد.');return false;} return true;
}
function escapeHtml(v=''){return String(v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}

window.JPRO_CLOUD={verifySignature:verifyCloudSignature,manualSync,uploadAttachment,listAttachments,downloadAttachment,deleteAttachment};
$('loginBtn').onclick=authLogin;
$('signupBtn').onclick=authSignup;
$('openCompanyBtn').onclick=openSelectedCompany;
$('createCompanyBtn').onclick=createCompany;
$('syncBtn').onclick=manualSync;
$('logoutBtn').onclick=logout;
$('cloudToggle').onclick=()=>$('cloudPanel').classList.toggle('hidden');
$('cloudClose').onclick=()=>$('cloudPanel').classList.add('hidden');

await initSupabase();
configGuard();
if(supabase){
  const {data:{session}}=await supabase.auth.getSession();
  if(session?.user) await afterAuth(session.user);
}
