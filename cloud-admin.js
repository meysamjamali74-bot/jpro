import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.111.0/+esm';

let cfg={...(window.JPRO_CONFIG||{})};
if(!cfg.SUPABASE_PUBLISHABLE_KEY && cfg.CONFIG_ENDPOINT){
  try{const r=await fetch(cfg.CONFIG_ENDPOINT,{cache:'no-store'});if(r.ok)cfg={...cfg,...await r.json()}}catch{}
}
const sb=(cfg.SUPABASE_URL&&cfg.SUPABASE_PUBLISHABLE_KEY)?createClient(cfg.SUPABASE_URL,cfg.SUPABASE_PUBLISHABLE_KEY,{auth:{persistSession:true,autoRefreshToken:true}}):null;
const ROLES={admin:'مدیر سیستم',ceo:'مدیرعامل',finance:'مالی',accountant:'حسابدار',treasury:'خزانه‌دار',cashier:'صندوقدار',sales_manager:'مدیر فروش',seller:'فروشنده',warehouse:'انباردار',logistics:'لجستیک',hr:'منابع انسانی',auditor:'حسابرس',requester:'متقاضی'};
const esc=(v='')=>String(v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const roleOptions=(selected='')=>Object.entries(ROLES).map(([k,v])=>`<option value="${k}" ${k===selected?'selected':''}>${v}</option>`).join('');
const unitOptions=(units,selected='')=>`<option value="">بدون واحد</option>`+units.map(u=>`<option value="${u.id}" ${u.id===selected?'selected':''}>${esc(u.name)}</option>`).join('');

async function context(){
  if(!sb||!window.JPRO_CLOUD?.company||!window.JPRO_CLOUD?.user)return null;
  const company=window.JPRO_CLOUD.company,user=window.JPRO_CLOUD.user;
  const {data,error}=await sb.from('company_memberships').select('role').eq('company_id',company.id).eq('user_id',user.id).maybeSingle();
  if(error)throw error;return{company,user,role:data?.role||''};
}

async function openMembers(){
  try{
    const ctx=await context();if(!ctx)return alert('ابتدا وارد یک شرکت شوید.');
    if(!['admin','ceo'].includes(ctx.role))return alert('مدیریت کاربران فقط برای مدیر سیستم/مدیرعامل مجاز است.');
    const [{data:reqs,error:rErr},{data:members,error:mErr},{data:units,error:uErr}]=await Promise.all([
      sb.rpc('admin_list_join_requests',{p_company:ctx.company.id}),
      sb.rpc('admin_list_members',{p_company:ctx.company.id}),
      sb.from('units').select('id,name,code,active').eq('company_id',ctx.company.id).eq('active',true).order('name')
    ]);
    if(rErr)throw rErr;if(mErr)throw mErr;if(uErr)throw uErr;
    document.getElementById('jproMembersModal')?.remove();
    const m=document.createElement('div');m.id='jproMembersModal';m.style.cssText='position:fixed;inset:0;z-index:4000;background:rgba(15,35,59,.42);display:grid;place-items:center;padding:18px;font-family:"B Nazanin",Tahoma,sans-serif;font-weight:700';
    m.innerHTML=`<div style="width:min(980px,96vw);max-height:90vh;overflow:auto;background:#fff;border-radius:16px;padding:16px;box-shadow:0 25px 70px rgba(0,0,0,.25)">
      <div style="display:flex;justify-content:space-between;gap:10px;align-items:center;border-bottom:1px solid #e7edf3;padding-bottom:10px"><div><h2 style="margin:0;color:#17365D">مدیریت کاربران JPro</h2><div style="font-size:12px;color:#718096">${esc(ctx.company.name)} • کد عضویت: <b style="direction:ltr;display:inline-block;color:#17365D">${esc(ctx.company.join_code||'—')}</b></div></div><button id="jmClose" style="border:0;border-radius:8px;padding:6px 11px;font-size:18px">×</button></div>
      <h3 style="color:#17365D">درخواست‌های عضویت (${(reqs||[]).length})</h3>
      <div>${(reqs||[]).map(r=>`<div style="border:1px solid #dfe7ef;border-radius:10px;padding:9px;margin:7px 0"><b>${esc(r.full_name||r.email||r.user_id)}</b><div style="font-size:11px;color:#718096">${esc(r.email||'')} • ${new Date(r.created_at).toLocaleString('fa-IR')}</div><div style="display:grid;grid-template-columns:1fr 1fr auto auto;gap:6px;margin-top:7px"><select data-jm-role="${r.request_id}">${roleOptions(r.requested_role||'requester')}</select><select data-jm-unit="${r.request_id}">${unitOptions(units||[],'')}</select><button data-jm-approve="${r.request_id}" style="background:#17365D;color:#fff;border:0;border-radius:7px;padding:6px 9px">تأیید</button><button data-jm-reject="${r.request_id}" style="background:#fff0ef;color:#8d2b22;border:1px solid #ebc8c4;border-radius:7px;padding:6px 9px">رد</button></div>${r.note?`<div style="font-size:11px;margin-top:5px">${esc(r.note)}</div>`:''}</div>`).join('')||'<div style="color:#718096">درخواست منتظری وجود ندارد.</div>'}</div>
      <h3 style="color:#17365D;margin-top:18px">اعضای شرکت (${(members||[]).length})</h3>
      <div style="overflow:auto"><table style="width:100%;border-collapse:collapse;font-size:12px"><thead><tr style="background:#17365D;color:#fff"><th style="padding:7px">کاربر</th><th>نقش</th><th>واحد</th><th>فعال</th><th>عملیات</th></tr></thead><tbody>${(members||[]).map(x=>`<tr style="border-bottom:1px solid #e8edf2"><td style="padding:7px"><b>${esc(x.full_name||x.email||x.user_id)}</b><br><small>${esc(x.email||'')}</small></td><td><select data-mm-role="${x.user_id}">${roleOptions(x.role)}</select></td><td><select data-mm-unit="${x.user_id}">${unitOptions(units||[],x.unit_id||'')}</select></td><td style="text-align:center"><input type="checkbox" data-mm-active="${x.user_id}" ${x.active?'checked':''}></td><td><button data-mm-save="${x.user_id}" style="border:1px solid #cfd9e4;border-radius:7px;padding:5px 8px">ذخیره</button></td></tr>`).join('')}</tbody></table></div>
    </div>`;
    document.body.appendChild(m);document.getElementById('jmClose').onclick=()=>m.remove();
    m.querySelectorAll('[data-jm-approve]').forEach(b=>b.onclick=async()=>{const id=b.dataset.jmApprove,role=m.querySelector(`[data-jm-role="${id}"]`).value,unit=m.querySelector(`[data-jm-unit="${id}"]`).value||null;const{error}=await sb.rpc('admin_decide_join_request',{p_request_id:id,p_approve:true,p_role:role,p_unit_id:unit});if(error)return alert(error.message);m.remove();await openMembers()});
    m.querySelectorAll('[data-jm-reject]').forEach(b=>b.onclick=async()=>{if(!confirm('درخواست رد شود؟'))return;const{error}=await sb.rpc('admin_decide_join_request',{p_request_id:b.dataset.jmReject,p_approve:false,p_role:'requester',p_unit_id:null});if(error)return alert(error.message);m.remove();await openMembers()});
    m.querySelectorAll('[data-mm-save]').forEach(b=>b.onclick=async()=>{const id=b.dataset.mmSave,role=m.querySelector(`[data-mm-role="${id}"]`).value,unit=m.querySelector(`[data-mm-unit="${id}"]`).value||null,active=m.querySelector(`[data-mm-active="${id}"]`).checked;const{error}=await sb.rpc('admin_update_member',{p_company:ctx.company.id,p_user:id,p_role:role,p_unit_id:unit,p_active:active});if(error)return alert(error.message);alert('دسترسی کاربر ذخیره شد.')});
  }catch(err){console.error(err);alert('خطا در مدیریت کاربران: '+(err.message||err))}
}

document.getElementById('membersBtn')?.addEventListener('click',openMembers);
window.JPRO_MEMBER_ADMIN={open:openMembers};
