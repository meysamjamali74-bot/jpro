import { pool, withTransaction } from './db.js';
import { requireRole } from './auth.js';

const n=v=>Number(v||0);
const txt=v=>String(v??'').trim();
const fail=(m,s=400,d=null)=>{const e=new Error(m);e.status=s;e.details=d;throw e};
const wrap=fn=>async(req,res)=>{try{await fn(req,res)}catch(e){console.error('customer club offline error',e);res.status(e.status||400).json({error:e.message||'OPERATION_FAILED',details:e.details||undefined})}};
const allowedRoles=['CRM_MANAGER','SALES_MANAGER','SALES_PERSON','CUSTOMER_SERVICE'];
const managerial=req=>{const r=req.user?.roles||[];return r.includes('SUPER_ADMIN')||r.includes('CRM_MANAGER')||r.includes('SALES_MANAGER')};

function normalizeKey(v){return txt(v).toLowerCase().replace(/[\u200c\u200f\ufeff]/g,'').replace(/[ _\-\/]+/g,'');}
const aliases={
 name:['name','customer','customername','نام','ناممشتری','نامو‌نامخانوادگی','نامونامخانوادگی','عنوان'],
 code:['code','customercode','کد','کدمشتری'],
 partyType:['partytype','type','نوع','نوعشخص'],
 nationalId:['nationalid','nationalcode','کدملی','شناسهملی'],
 economicCode:['economiccode','کداقتصادی','شماره اقتصادی','شمارهاقتصادی'],
 mobile:['mobile','cellphone','شماره موبایل','شمارههمراه','موبایل','همراه'],
 phone:['phone','tel','تلفن','شمارهتلفن'],
 email:['email','ایمیل','پستالکترونیک'],
 province:['province','استان'],
 city:['city','شهر'],
 address:['address','آدرس','نشانی'],
 postalCode:['postalcode','zipcode','کدپستی'],
 notes:['notes','note','توضیحات','یادداشت'],
 source:['source','منبع','منبعجذب'],
 priority:['priority','اولویت'],
 lifecycleStatus:['status','lifecyclestatus','وضعیت','وضعیتمشتری'],
 nextActionAt:['nextactionat','nextfollowup','followupdate','تاریخپیگیری','پیگیریبعدی','زمانپیگیری'],
 nextActionTitle:['nextactiontitle','followupsubject','موضوعپیگیری','اقدامبعدی'],
 ownerEmail:['owneremail','useremail','کاربر','ایمیلکاربر','کارشناس'],
 tags:['tags','برچسب','برچسبها']
};
const aliasMap=new Map(Object.entries(aliases).flatMap(([k,vs])=>vs.map(v=>[normalizeKey(v),k])));

function parseCsv(text){
 const src=String(text||'').replace(/^\uFEFF/,'');
 if(!src.trim())return[];
 const first=(src.split(/\r?\n/,1)[0]||'');
 const counts={',':(first.match(/,/g)||[]).length,';':(first.match(/;/g)||[]).length,'\t':(first.match(/\t/g)||[]).length};
 const delimiter=Object.entries(counts).sort((a,b)=>b[1]-a[1])[0][0];
 const rows=[];let row=[],field='',quoted=false;
 for(let i=0;i<src.length;i++){
   const ch=src[i];
   if(ch==='"'){
     if(quoted&&src[i+1]==='"'){field+='"';i++;}else quoted=!quoted;
   }else if(ch===delimiter&&!quoted){row.push(field);field='';}
   else if((ch==='\n'||ch==='\r')&&!quoted){
     if(ch==='\r'&&src[i+1]==='\n')i++;
     row.push(field);field='';
     if(row.some(x=>txt(x)!==''))rows.push(row);
     row=[];
   }else field+=ch;
 }
 row.push(field);if(row.some(x=>txt(x)!==''))rows.push(row);
 if(rows.length<2)return[];
 const headers=rows[0].map(h=>aliasMap.get(normalizeKey(h))||null);
 return rows.slice(1).map((cells,idx)=>{const o={_rowNo:idx+2};headers.forEach((h,i)=>{if(h)o[h]=txt(cells[i])});return o});
}

function normalizeInputRow(r,rowNo=1){
 const o={...r};
 if(!Object.keys(o).some(k=>Object.values(aliases).flat().includes(k))){
   for(const [k,v] of Object.entries(r||{})){const mapped=aliasMap.get(normalizeKey(k));if(mapped)o[mapped]=v;}
 }
 o._rowNo=n(o._rowNo||rowNo);
 o.name=txt(o.name);o.code=txt(o.code)||null;o.nationalId=txt(o.nationalId)||null;o.economicCode=txt(o.economicCode)||null;
 o.mobile=txt(o.mobile).replace(/[\s\-()]/g,'')||null;o.phone=txt(o.phone)||null;o.email=txt(o.email)||null;
 o.province=txt(o.province)||null;o.city=txt(o.city)||null;o.address=txt(o.address)||null;o.postalCode=txt(o.postalCode)||null;o.notes=txt(o.notes)||null;
 o.partyType=['NATURAL','LEGAL'].includes(txt(o.partyType).toUpperCase())?txt(o.partyType).toUpperCase():'NATURAL';
 const st=txt(o.lifecycleStatus).toUpperCase();o.lifecycleStatus=['NEW','ACTIVE','PAUSED','WON','LOST','DO_NOT_CONTACT'].includes(st)?st:'NEW';
 const pr=txt(o.priority).toUpperCase();o.priority=['LOW','NORMAL','HIGH','CRITICAL'].includes(pr)?pr:'NORMAL';
 o.source=txt(o.source)||null;o.nextActionAt=txt(o.nextActionAt)||null;o.nextActionTitle=txt(o.nextActionTitle)||null;o.ownerEmail=txt(o.ownerEmail).toLowerCase()||null;
 o.tags=Array.isArray(o.tags)?o.tags:txt(o.tags)?txt(o.tags).split(/[،,;]+/).map(txt).filter(Boolean):[];
 return o;
}

async function validateOwner(conn,companyId,userId){
 if(!userId)fail('مسئول پیگیری الزامی است.',422);
 const [u]=await conn.execute('SELECT id,full_name,email,is_active FROM users WHERE id=? AND company_id=?',[userId,companyId]);
 if(!u.length||!u[0].is_active)fail('کاربر مسئول پیگیری معتبر یا فعال نیست.',422);
 return u[0];
}
async function ownerByEmail(conn,companyId,email){if(!email)return null;const [u]=await conn.execute('SELECT id FROM users WHERE company_id=? AND email=? AND is_active=1',[companyId,email]);return u[0]?.id||null;}
async function nextNo(conn,c,type,prefix){
 const lock=`trz:cc:${c}:${type}`;const [[g]]=await conn.query('SELECT GET_LOCK(?,5) got',[lock]);if(!g?.got)fail('شماره‌گذاری باشگاه مشتریان موقتاً درگیر است.',409);
 try{let [r]=await conn.execute(`SELECT id,last_number,prefix,pad_length FROM document_sequences WHERE company_id=? AND branch_id IS NULL AND fiscal_year_id IS NULL AND document_type=? ORDER BY id LIMIT 1 FOR UPDATE`,[c,type]);if(!r.length){await conn.execute('INSERT INTO document_sequences(company_id,document_type,prefix,last_number,pad_length) VALUES (?,?,?,0,6)',[c,type,prefix]);[r]=await conn.execute(`SELECT id,last_number,prefix,pad_length FROM document_sequences WHERE company_id=? AND branch_id IS NULL AND fiscal_year_id IS NULL AND document_type=? ORDER BY id LIMIT 1 FOR UPDATE`,[c,type])}const x=r[0],v=n(x.last_number)+1;await conn.execute('UPDATE document_sequences SET last_number=? WHERE id=?',[v,x.id]);return `${x.prefix||prefix}-${String(v).padStart(Number(x.pad_length||6),'0')}`}finally{await conn.query('SELECT RELEASE_LOCK(?)',[lock])}
}
async function ensureLoyaltyAccount(conn,c,partyId){
 const [old]=await conn.execute('SELECT id,member_no FROM loyalty_accounts WHERE company_id=? AND party_id=?',[c,partyId]);if(old.length)return old[0];
 const memberNo=await nextNo(conn,c,'LOYALTY_MEMBER','MEM');const [tier]=await conn.execute('SELECT id FROM loyalty_tiers WHERE company_id=? AND is_active=1 ORDER BY priority,min_points,id LIMIT 1',[c]);
 const [r]=await conn.execute("INSERT INTO loyalty_accounts(company_id,party_id,member_no,tier_id,status) VALUES (?,?,?,?, 'ACTIVE')",[c,partyId,memberNo,tier[0]?.id||null]);return{id:r.insertId,member_no:memberNo};
}
async function upsertCustomer(conn,c,row,defaultOwner,userId){
 let ownerId=(await ownerByEmail(conn,c,row.ownerEmail))||n(row.ownerUserId)||n(defaultOwner)||n(userId);await validateOwner(conn,c,ownerId);
 let party=null;
 if(row.nationalId){const [r]=await conn.execute('SELECT * FROM parties WHERE company_id=? AND national_id=? AND is_deleted=0 LIMIT 1',[c,row.nationalId]);party=r[0]||null;}
 if(!party&&row.mobile){const [r]=await conn.execute('SELECT * FROM parties WHERE company_id=? AND mobile=? AND is_deleted=0 LIMIT 1',[c,row.mobile]);party=r[0]||null;}
 if(!party&&row.code){const [r]=await conn.execute('SELECT * FROM parties WHERE company_id=? AND code=? AND is_deleted=0 LIMIT 1',[c,row.code]);party=r[0]||null;}
 let inserted=false,partyId;
 if(party){partyId=party.id;await conn.execute(`UPDATE parties SET name=?,party_type=?,code=COALESCE(?,code),national_id=COALESCE(?,national_id),economic_code=COALESCE(?,economic_code),mobile=COALESCE(?,mobile),phone=COALESCE(?,phone),email=COALESCE(?,email),province=COALESCE(?,province),city=COALESCE(?,city),address=COALESCE(?,address),postal_code=COALESCE(?,postal_code),notes=COALESCE(?,notes),is_active=1 WHERE id=? AND company_id=?`,[row.name,row.partyType,row.code,row.nationalId,row.economicCode,row.mobile,row.phone,row.email,row.province,row.city,row.address,row.postalCode,row.notes,partyId,c]);}
 else{const [r]=await conn.execute(`INSERT INTO parties(company_id,party_type,code,name,national_id,economic_code,mobile,phone,email,address,postal_code,province,city,notes,is_active) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,1)`,[c,row.partyType,row.code,row.name,row.nationalId,row.economicCode,row.mobile,row.phone,row.email,row.address,row.postalCode,row.province,row.city,row.notes]);partyId=r.insertId;inserted=true;}
 await conn.execute("INSERT IGNORE INTO party_roles(party_id,role_code) VALUES (?,'CUSTOMER')",[partyId]);
 await conn.execute('INSERT IGNORE INTO customer_profiles(party_id,credit_limit,payment_terms_days,discount_limit_pct) VALUES (?,0,0,0)',[partyId]);
 const loyalty=await ensureLoyaltyAccount(conn,c,partyId);
 await conn.execute(`INSERT INTO customer_club_assignments(company_id,party_id,owner_user_id,lifecycle_status,priority,source,next_action_at,next_action_title,tags_json,created_by,updated_by) VALUES (?,?,?,?,?,?,?,?,?,?,?) ON DUPLICATE KEY UPDATE owner_user_id=VALUES(owner_user_id),lifecycle_status=VALUES(lifecycle_status),priority=VALUES(priority),source=COALESCE(VALUES(source),source),next_action_at=COALESCE(VALUES(next_action_at),next_action_at),next_action_title=COALESCE(VALUES(next_action_title),next_action_title),tags_json=COALESCE(VALUES(tags_json),tags_json),updated_by=VALUES(updated_by)`,[c,partyId,ownerId,row.lifecycleStatus,row.priority,row.source,row.nextActionAt,row.nextActionTitle,row.tags.length?JSON.stringify(row.tags):null,userId,userId]);
 if(row.nextActionAt||row.nextActionTitle){await conn.execute(`INSERT INTO crm_activities(company_id,party_id,activity_type,subject,description,owner_user_id,scheduled_at,status,created_by) VALUES (?,?,'FOLLOW_UP',?,?,?,?,'OPEN',?)`,[c,partyId,row.nextActionTitle||'پیگیری مشتری باشگاه',row.notes,ownerId,row.nextActionAt,userId]);}
 return{partyId,inserted,ownerId,memberNo:loyalty.member_no};
}

export function registerCustomerClubOfflineRoutes(app){
 app.get('/api/system/runtime',wrap(async(req,res)=>{const [[db]]=await pool.query('SELECT VERSION() version,@@hostname hostname,@@port port,DATABASE() db');res.json({mode:'OFFLINE_LAN',internetRequired:false,database:'MySQL',databaseVersion:db.version,databaseHost:db.hostname,databasePort:db.port,databaseName:db.db,apiBind:'0.0.0.0',webPort:Number(process.env.PORT||8080)})}));

 app.get('/api/iran/customer-club/users',requireRole(...allowedRoles),wrap(async(req,res)=>{const [rows]=await pool.execute(`SELECT u.id,u.full_name,u.email,GROUP_CONCAT(r.code ORDER BY r.code) roles FROM users u LEFT JOIN user_roles ur ON ur.user_id=u.id LEFT JOIN roles r ON r.id=ur.role_id WHERE u.company_id=? AND u.is_active=1 GROUP BY u.id ORDER BY u.full_name`,[req.user.companyId]);res.json(rows)}));

 app.get('/api/iran/customer-club/dashboard',requireRole(...allowedRoles),wrap(async(req,res)=>{const c=req.user.companyId,userId=Number(req.user.sub),team=managerial(req);const ownerSql=team?'':' AND owner_user_id=?',p=team?[c]:[c,userId];const [[x]]=await pool.execute(`SELECT COUNT(*) customers,SUM(lifecycle_status='NEW') new_customers,SUM(lifecycle_status='ACTIVE') active_customers,SUM(lifecycle_status='PAUSED') paused_customers,SUM(next_action_at IS NOT NULL AND next_action_at<CURRENT_TIMESTAMP AND lifecycle_status IN ('NEW','ACTIVE')) overdue,SUM(next_action_at IS NOT NULL AND DATE(next_action_at)=CURRENT_DATE AND lifecycle_status IN ('NEW','ACTIVE')) due_today,SUM(owner_user_id IS NULL) unassigned FROM customer_club_assignments WHERE company_id=?${ownerSql}`,p);const [byOwner]=team?await pool.execute(`SELECT a.owner_user_id,u.full_name owner_name,COUNT(*) customers,SUM(a.next_action_at<CURRENT_TIMESTAMP AND a.lifecycle_status IN ('NEW','ACTIVE')) overdue,SUM(DATE(a.next_action_at)=CURRENT_DATE AND a.lifecycle_status IN ('NEW','ACTIVE')) due_today FROM customer_club_assignments a JOIN users u ON u.id=a.owner_user_id WHERE a.company_id=? GROUP BY a.owner_user_id,u.full_name ORDER BY overdue DESC,due_today DESC,customers DESC`,[c]):[[]];res.json({...x,byOwner})}));

 app.get('/api/iran/customer-club/customers',requireRole(...allowedRoles),wrap(async(req,res)=>{const c=req.user.companyId,q=txt(req.query.q),status=txt(req.query.status).toUpperCase(),due=txt(req.query.due).toLowerCase(),owner=n(req.query.ownerUserId),team=managerial(req);const w=['a.company_id=?'],p=[c];if(!team){w.push('a.owner_user_id=?');p.push(Number(req.user.sub))}else if(owner){w.push('a.owner_user_id=?');p.push(owner)}if(status){w.push('a.lifecycle_status=?');p.push(status)}if(q){const like=`%${q}%`;w.push('(p.name LIKE ? OR p.code LIKE ? OR p.mobile LIKE ? OR p.national_id LIKE ? OR la.member_no LIKE ?)');p.push(like,like,like,like,like)}if(due==='overdue')w.push("a.lifecycle_status IN ('NEW','ACTIVE') AND a.next_action_at<CURRENT_TIMESTAMP");if(due==='today')w.push("a.lifecycle_status IN ('NEW','ACTIVE') AND DATE(a.next_action_at)=CURRENT_DATE");if(due==='upcoming')w.push("a.lifecycle_status IN ('NEW','ACTIVE') AND a.next_action_at>CURRENT_TIMESTAMP");const [rows]=await pool.execute(`SELECT a.*,p.code,p.name,p.party_type,p.national_id,p.economic_code,p.mobile,p.phone,p.email,p.province,p.city,p.address,p.postal_code,p.notes,u.full_name owner_name,u.email owner_email,la.member_no,la.points_balance,la.wallet_balance,lt.title tier_title,(SELECT MAX(ca.completed_at) FROM crm_activities ca WHERE ca.company_id=a.company_id AND ca.party_id=a.party_id AND ca.status='COMPLETED') last_activity_at,(SELECT COUNT(*) FROM crm_activities ca WHERE ca.company_id=a.company_id AND ca.party_id=a.party_id AND ca.status IN ('OPEN','IN_PROGRESS') AND ca.scheduled_at<CURRENT_TIMESTAMP) overdue_followups FROM customer_club_assignments a JOIN parties p ON p.id=a.party_id JOIN users u ON u.id=a.owner_user_id LEFT JOIN loyalty_accounts la ON la.company_id=a.company_id AND la.party_id=a.party_id LEFT JOIN loyalty_tiers lt ON lt.id=la.tier_id WHERE ${w.join(' AND ')} ORDER BY FIELD(a.priority,'CRITICAL','HIGH','NORMAL','LOW'),COALESCE(a.next_action_at,'2999-12-31'),a.id DESC LIMIT 1000`,p);res.json(rows)}));

 app.post('/api/iran/customer-club/customers',requireRole(...allowedRoles),wrap(async(req,res)=>{const row=normalizeInputRow(req.body||{},1);if(!row.name)fail('نام مشتری الزامی است.',422);const result=await withTransaction(conn=>upsertCustomer(conn,req.user.companyId,row,req.body?.ownerUserId,Number(req.user.sub)));res.status(result.inserted?201:200).json(result)}));

 app.put('/api/iran/customer-club/customers/:partyId/assignment',requireRole(...allowedRoles),wrap(async(req,res)=>{const c=req.user.companyId,partyId=Number(req.params.partyId),b=req.body||{},ownerId=n(b.ownerUserId)||Number(req.user.sub);if(!managerial(req)&&ownerId!==Number(req.user.sub))fail('ارجاع مشتری به کاربر دیگر فقط توسط مدیر مجاز است.',403);await withTransaction(async conn=>{await validateOwner(conn,c,ownerId);const [r]=await conn.execute(`UPDATE customer_club_assignments SET owner_user_id=?,lifecycle_status=COALESCE(?,lifecycle_status),priority=COALESCE(?,priority),next_action_at=?,next_action_title=?,updated_by=? WHERE company_id=? AND party_id=?`,[ownerId,b.lifecycleStatus||null,b.priority||null,b.nextActionAt||null,b.nextActionTitle||null,Number(req.user.sub),c,partyId]);if(!r.affectedRows)fail('مشتری باشگاه پیدا نشد.',404)});res.json({ok:true})}));

 app.post('/api/iran/customer-club/customers/:partyId/followups',requireRole(...allowedRoles),wrap(async(req,res)=>{const c=req.user.companyId,partyId=Number(req.params.partyId),b=req.body||{};if(!txt(b.subject))fail('موضوع پیگیری الزامی است.',422);const result=await withTransaction(async conn=>{const [a]=await conn.execute('SELECT * FROM customer_club_assignments WHERE company_id=? AND party_id=? FOR UPDATE',[c,partyId]);if(!a.length)fail('مشتری باشگاه پیدا نشد.',404);if(!managerial(req)&&Number(a[0].owner_user_id)!==Number(req.user.sub))fail('این مشتری به شما تخصیص داده نشده است.',403);const ownerId=n(b.ownerUserId)||Number(a[0].owner_user_id);if(!managerial(req)&&ownerId!==Number(req.user.sub))fail('ارجاع پیگیری به کاربر دیگر فقط توسط مدیر مجاز است.',403);await validateOwner(conn,c,ownerId);const type=['CALL','MEETING','VISIT','EMAIL','MESSAGE','FOLLOW_UP','NOTE','TASK'].includes(txt(b.activityType).toUpperCase())?txt(b.activityType).toUpperCase():'FOLLOW_UP';const [r]=await conn.execute(`INSERT INTO crm_activities(company_id,party_id,activity_type,subject,description,owner_user_id,scheduled_at,next_action_at,next_action_title,status,created_by) VALUES (?,?,?,?,?,?,?,?,?,'OPEN',?)`,[c,partyId,type,b.subject,b.description||null,ownerId,b.scheduledAt||b.nextActionAt||null,b.nextActionAt||null,b.nextActionTitle||null,Number(req.user.sub)]);await conn.execute(`UPDATE customer_club_assignments SET owner_user_id=?,lifecycle_status=IF(lifecycle_status='NEW','ACTIVE',lifecycle_status),next_action_at=?,next_action_title=?,updated_by=? WHERE company_id=? AND party_id=?`,[ownerId,b.scheduledAt||b.nextActionAt||null,b.nextActionTitle||b.subject,Number(req.user.sub),c,partyId]);return{id:r.insertId}});res.status(201).json(result)}));

 app.get('/api/iran/customer-club/followups',requireRole(...allowedRoles),wrap(async(req,res)=>{const c=req.user.companyId,team=managerial(req),due=txt(req.query.due).toLowerCase(),status=txt(req.query.status).toUpperCase(),owner=n(req.query.ownerUserId),w=['ca.company_id=?','ca.party_id IS NOT NULL'],p=[c];if(!team){w.push('ca.owner_user_id=?');p.push(Number(req.user.sub))}else if(owner){w.push('ca.owner_user_id=?');p.push(owner)}if(status){w.push('ca.status=?');p.push(status)}if(due==='overdue')w.push("ca.status IN ('OPEN','IN_PROGRESS') AND ca.scheduled_at<CURRENT_TIMESTAMP");if(due==='today')w.push("ca.status IN ('OPEN','IN_PROGRESS') AND DATE(ca.scheduled_at)=CURRENT_DATE");if(due==='upcoming')w.push("ca.status IN ('OPEN','IN_PROGRESS') AND ca.scheduled_at>CURRENT_TIMESTAMP");const [rows]=await pool.execute(`SELECT ca.*,p.name customer,p.mobile,u.full_name owner_name,a.lifecycle_status,a.priority FROM crm_activities ca JOIN parties p ON p.id=ca.party_id JOIN users u ON u.id=ca.owner_user_id LEFT JOIN customer_club_assignments a ON a.company_id=ca.company_id AND a.party_id=ca.party_id WHERE ${w.join(' AND ')} ORDER BY FIELD(a.priority,'CRITICAL','HIGH','NORMAL','LOW'),COALESCE(ca.scheduled_at,'2999-12-31'),ca.id DESC LIMIT 1000`,p);res.json(rows)}));

 app.put('/api/iran/customer-club/followups/:id/complete',requireRole(...allowedRoles),wrap(async(req,res)=>{const c=req.user.companyId,id=Number(req.params.id),b=req.body||{};if(!txt(b.result))fail('ثبت نتیجه پیگیری الزامی است.',422);const result=await withTransaction(async conn=>{const [rows]=await conn.execute('SELECT * FROM crm_activities WHERE id=? AND company_id=? FOR UPDATE',[id,c]);if(!rows.length)fail('پیگیری پیدا نشد.',404);const a=rows[0];if(!managerial(req)&&Number(a.owner_user_id)!==Number(req.user.sub))fail('این پیگیری متعلق به شما نیست.',403);await conn.execute("UPDATE crm_activities SET status='COMPLETED',completed_at=NOW(),result=?,next_action_at=?,next_action_title=? WHERE id=?",[b.result,b.nextActionAt||null,b.nextActionTitle||null,id]);await conn.execute(`UPDATE customer_club_assignments SET lifecycle_status=COALESCE(?,IF(lifecycle_status='NEW','ACTIVE',lifecycle_status)),last_contact_at=NOW(),last_result=?,next_action_at=?,next_action_title=?,updated_by=? WHERE company_id=? AND party_id=?`,[b.lifecycleStatus||null,b.result,b.nextActionAt||null,b.nextActionTitle||null,Number(req.user.sub),c,a.party_id]);let nextActivityId=null;if(b.nextActionAt||b.nextActionTitle){const [r]=await conn.execute(`INSERT INTO crm_activities(company_id,party_id,activity_type,subject,description,owner_user_id,scheduled_at,status,created_by) VALUES (?,?,'FOLLOW_UP',?,?,?,?,'OPEN',?)`,[c,a.party_id,b.nextActionTitle||'پیگیری بعدی',b.nextDescription||null,a.owner_user_id,b.nextActionAt||null,Number(req.user.sub)]);nextActivityId=r.insertId}return{ok:true,nextActivityId}});res.json(result)}));

 app.post('/api/iran/customer-club/import',requireRole('CRM_MANAGER','SALES_MANAGER','CUSTOMER_SERVICE'),wrap(async(req,res)=>{const c=req.user.companyId,b=req.body||{};let rows=Array.isArray(b.rows)?b.rows.map((r,i)=>normalizeInputRow(r,i+1)):parseCsv(b.csvText).map((r,i)=>normalizeInputRow(r,i+2));if(!rows.length)fail('فایل/داده واردشده فاقد ردیف قابل پردازش است.',422);if(rows.length>10000)fail('حداکثر ۱۰٬۰۰۰ ردیف در هر بار ورود مجاز است.',422);const result=await withTransaction(async conn=>{const defaultOwner=n(b.defaultOwnerUserId)||Number(req.user.sub);await validateOwner(conn,c,defaultOwner);const [batch]=await conn.execute(`INSERT INTO customer_club_import_batches(company_id,source_name,source_type,status,total_rows,default_owner_user_id,default_source,created_by) VALUES (?,?,?,'PROCESSING',?,?,?,?)`,[c,b.sourceName||null,Array.isArray(b.rows)?'API':'CSV',rows.length,defaultOwner,b.defaultSource||null,Number(req.user.sub)]);let inserted=0,updated=0,rejected=0;const errors=[];for(let i=0;i<rows.length;i++){const row=rows[i];if(!row.source)row.source=b.defaultSource||null;try{if(!row.name)throw new Error('نام مشتری خالی است.');const r=await upsertCustomer(conn,c,row,defaultOwner,Number(req.user.sub));if(r.inserted)inserted++;else updated++;await conn.execute(`INSERT INTO customer_club_import_rows(batch_id,row_no,party_id,row_status,identity_key,payload_json) VALUES (?,?,?,?,?,?)`,[batch.insertId,row._rowNo||i+1,r.partyId,r.inserted?'INSERTED':'UPDATED',row.nationalId||row.mobile||row.code||row.name,JSON.stringify(row)]);}catch(e){rejected++;errors.push({rowNo:row._rowNo||i+1,error:e.message});await conn.execute(`INSERT INTO customer_club_import_rows(batch_id,row_no,row_status,identity_key,error_message,payload_json) VALUES (?,?,'REJECTED',?,?,?)`,[batch.insertId,row._rowNo||i+1,row.nationalId||row.mobile||row.code||row.name||null,String(e.message).slice(0,1000),JSON.stringify(row)])}}const status=rejected?'COMPLETED_WITH_ERRORS':'COMPLETED';await conn.execute('UPDATE customer_club_import_batches SET status=?,inserted_rows=?,updated_rows=?,rejected_rows=?,completed_at=NOW() WHERE id=?',[status,inserted,updated,rejected,batch.insertId]);return{batchId:batch.insertId,status,total:rows.length,inserted,updated,rejected,errors:errors.slice(0,100)}});res.json(result)}));

 app.get('/api/iran/customer-club/imports',requireRole('CRM_MANAGER','SALES_MANAGER','CUSTOMER_SERVICE'),wrap(async(req,res)=>{const [rows]=await pool.execute(`SELECT b.*,u.full_name created_by_name,o.full_name default_owner_name FROM customer_club_import_batches b JOIN users u ON u.id=b.created_by LEFT JOIN users o ON o.id=b.default_owner_user_id WHERE b.company_id=? ORDER BY b.id DESC LIMIT 200`,[req.user.companyId]);res.json(rows)}));
 app.get('/api/iran/customer-club/imports/:id/errors',requireRole('CRM_MANAGER','SALES_MANAGER','CUSTOMER_SERVICE'),wrap(async(req,res)=>{const [rows]=await pool.execute(`SELECT r.row_no,r.identity_key,r.error_message,r.payload_json FROM customer_club_import_rows r JOIN customer_club_import_batches b ON b.id=r.batch_id WHERE b.company_id=? AND b.id=? AND r.row_status='REJECTED' ORDER BY r.row_no`,[req.user.companyId,Number(req.params.id)]);res.json(rows)}));
}

export { parseCsv, normalizeInputRow };
