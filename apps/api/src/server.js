import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import bcrypt from 'bcryptjs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { pool, migrate, healthCheck, withTransaction } from './db.js';
import { authenticate, requireAuth, requireRole } from './auth.js';
import { calculateCommission } from './commission.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '../../..');
const webDir = path.join(rootDir, 'apps/web');
const app = express();
app.disable('x-powered-by');
app.use(helmet({ contentSecurityPolicy: false }));
app.use(cors({ origin: true, credentials: false }));
app.use(express.json({ limit: '2mb' }));

async function audit(req, action, entityType, entityId = null, beforeValue = null, afterValue = null) {
  try {
    await pool.execute(
      `INSERT INTO audit_logs(company_id,user_id,action,entity_type,entity_id,before_json,after_json,ip_address,user_agent)
       VALUES (?,?,?,?,?,?,?,?,?)`,
      [req.user?.companyId || null, Number(req.user?.sub) || null, action, entityType, entityId,
       beforeValue ? JSON.stringify(beforeValue) : null, afterValue ? JSON.stringify(afterValue) : null,
       req.ip, req.headers['user-agent'] || null]
    );
  } catch (error) { console.error('audit failed', error.message); }
}

async function bootstrapAdmin() {
  const adminEmail = process.env.TARAZPAD_ADMIN_EMAIL || 'admin@tarazpad.local';
  const adminPassword = process.env.TARAZPAD_ADMIN_PASSWORD || 'ChangeMe_Immediately_2026!';
  const adminName = process.env.TARAZPAD_ADMIN_NAME || 'مدیر سیستم';
  const passwordHash = await bcrypt.hash(adminPassword, 12);
  await withTransaction(async conn => {
    const [companies] = await conn.execute('SELECT id FROM companies ORDER BY id LIMIT 1');
    let companyId = companies[0]?.id;
    if (!companyId) { const [r] = await conn.execute('INSERT INTO companies(code,name,is_active) VALUES (?,?,1)', ['TRZ','ترازپاد']); companyId = r.insertId; }
    await conn.execute(`INSERT INTO roles(code,title,is_system) VALUES
      ('SUPER_ADMIN','مدیر کل سیستم',1),('FINANCE_MANAGER','مدیر مالی',1),('ACCOUNTANT','حسابدار',1),
      ('SALES_MANAGER','مدیر فروش',1),('SALES_PERSON','فروشنده',1),('WAREHOUSE_MANAGER','مدیر انبار',1),
      ('LOGISTICS_MANAGER','مدیر لجستیک',1),('HR_MANAGER','مدیر منابع انسانی',1)
      ON DUPLICATE KEY UPDATE title=VALUES(title)`);
    const [users] = await conn.execute('SELECT id FROM users WHERE email=?',[adminEmail]); let userId=users[0]?.id;
    if(!userId){const [r]=await conn.execute('INSERT INTO users(company_id,full_name,email,password_hash,is_active) VALUES (?,?,?,?,1)',[companyId,adminName,adminEmail,passwordHash]);userId=r.insertId;}
    const [roles]=await conn.execute("SELECT id FROM roles WHERE code='SUPER_ADMIN'");
    await conn.execute('INSERT IGNORE INTO user_roles(user_id,role_id) VALUES (?,?)',[userId,roles[0].id]);
  });
}

app.get('/api/health', async (_req,res)=>{try{res.json({ok:await healthCheck(),service:'tarazpad-api',version:'0.1.0'})}catch(e){res.status(503).json({ok:false,error:e.message})}});
app.post('/api/auth/login', async (req,res)=>{const {email,password}=req.body||{};if(!email||!password)return res.status(400).json({error:'EMAIL_AND_PASSWORD_REQUIRED'});const result=await authenticate(String(email).trim().toLowerCase(),String(password));if(!result)return res.status(401).json({error:'INVALID_CREDENTIALS'});res.json(result)});
app.use('/api',requireAuth);
app.get('/api/me',(req,res)=>res.json({user:req.user}));
app.get('/api/preferences',async(req,res)=>{const [rows]=await pool.execute('SELECT preferences_json FROM user_preferences WHERE user_id=?',[Number(req.user.sub)]);res.json(rows[0]?.preferences_json||{})});
app.put('/api/preferences',async(req,res)=>{const payload=req.body||{};await pool.execute(`INSERT INTO user_preferences(user_id,preferences_json) VALUES (?,?) ON DUPLICATE KEY UPDATE preferences_json=VALUES(preferences_json),updated_at=CURRENT_TIMESTAMP`,[Number(req.user.sub),JSON.stringify(payload)]);await audit(req,'UPDATE','user_preferences',req.user.sub,null,payload);res.json({ok:true})});
app.get('/api/dashboard/layout',async(req,res)=>{const [rows]=await pool.execute("SELECT layout_json FROM dashboard_layouts WHERE user_id=? AND dashboard_key='main'",[Number(req.user.sub)]);res.json(rows[0]?.layout_json||null)});
app.put('/api/dashboard/layout',async(req,res)=>{await pool.execute(`INSERT INTO dashboard_layouts(user_id,dashboard_key,layout_json) VALUES (?,'main',?) ON DUPLICATE KEY UPDATE layout_json=VALUES(layout_json),updated_at=CURRENT_TIMESTAMP`,[Number(req.user.sub),JSON.stringify(req.body||[])]);res.json({ok:true})});
app.get('/api/dashboard/summary',async(req,res)=>{const companyId=req.user.companyId;const [[sales]]=await pool.query(`SELECT COALESCE(SUM(CASE WHEN invoice_date=CURRENT_DATE THEN net_total ELSE 0 END),0) sales_today,COALESCE(SUM(CASE WHEN YEAR(invoice_date)=YEAR(CURRENT_DATE) AND MONTH(invoice_date)=MONTH(CURRENT_DATE) THEN net_total ELSE 0 END),0) sales_month,COALESCE(SUM(CASE WHEN status IN ('OUTSTANDING','OVERDUE') THEN outstanding_amount ELSE 0 END),0) ar_open,COALESCE(SUM(CASE WHEN status='OVERDUE' THEN outstanding_amount ELSE 0 END),0) ar_overdue FROM sales_invoices WHERE company_id=? AND is_void=0`,[companyId]);const [[inventory]]=await pool.query('SELECT COALESCE(SUM(on_hand_qty*average_cost),0) inventory_value,COALESCE(SUM(reserved_qty),0) reserved_qty FROM inventory_balances WHERE company_id=?',[companyId]);const [[tasks]]=await pool.query("SELECT COUNT(*) open_tasks,SUM(status='OVERDUE') overdue_tasks FROM tasks WHERE company_id=? AND status NOT IN ('COMPLETED','CANCELLED')",[companyId]);const [[trips]]=await pool.query("SELECT COUNT(*) trips_today,COALESCE(SUM(status IN ('DISPATCHED','IN_ROUTE')),0) trips_in_route FROM trips WHERE company_id=? AND trip_date=CURRENT_DATE",[companyId]);const [[cash]]=await pool.query(`SELECT COALESCE((SELECT SUM(amount) FROM receipts WHERE company_id=? AND status='POSTED'),0)-COALESCE((SELECT SUM(amount) FROM payments WHERE company_id=? AND status='POSTED'),0) cash_position`,[companyId,companyId]);res.json({...sales,...inventory,...tasks,...trips,...cash,gross_profit:0,collection_rate:0})});

app.get('/api/status/:domain',async(req,res)=>{const domain=req.params.domain,companyId=req.user.companyId;if(domain==='warehouse'){const [rows]=await pool.query(`SELECT 'AVAILABLE' status,COUNT(*) count,COALESCE(SUM(GREATEST(on_hand_qty-reserved_qty-quarantine_qty-damaged_qty,0)),0) amount FROM inventory_balances WHERE company_id=? UNION ALL SELECT 'RESERVED',COUNT(*),COALESCE(SUM(reserved_qty),0) FROM inventory_balances WHERE company_id=? AND reserved_qty>0 UNION ALL SELECT 'QUARANTINE',COUNT(*),COALESCE(SUM(quarantine_qty),0) FROM inventory_balances WHERE company_id=? AND quarantine_qty>0 UNION ALL SELECT 'DAMAGED',COUNT(*),COALESCE(SUM(damaged_qty),0) FROM inventory_balances WHERE company_id=? AND damaged_qty>0`,[companyId,companyId,companyId,companyId]);return res.json(rows)}const config={sales:['sales_invoices','status','net_total'],purchases:['purchase_invoices','status','net_total'],logistics:['trips','status','NULL'],tasks:['tasks','status','NULL']}[domain];if(!config)return res.status(404).json({error:'UNKNOWN_DOMAIN'});const [table,statusCol,amountCol]=config;const sql=`SELECT ${statusCol} status,COUNT(*) count${amountCol!=='NULL'?`,COALESCE(SUM(${amountCol}),0) amount`:`,0 amount`} FROM ${table} WHERE company_id=? GROUP BY ${statusCol}`;const [rows]=await pool.query(sql,[companyId]);res.json(rows)});

app.get('/api/parties',async(req,res)=>{const q=`%${String(req.query.q||'').trim()}%`;const [rows]=await pool.execute(`SELECT p.*,cp.credit_limit,cp.payment_terms_days FROM parties p LEFT JOIN customer_profiles cp ON cp.party_id=p.id WHERE p.company_id=? AND p.is_deleted=0 AND (p.name LIKE ? OR p.national_id LIKE ? OR p.mobile LIKE ?) ORDER BY p.id DESC LIMIT 200`,[req.user.companyId,q,q,q]);res.json(rows)});
app.post('/api/parties',async(req,res)=>{const {name,partyType='LEGAL',nationalId=null,mobile=null,roles=['CUSTOMER']}=req.body||{};if(!name)return res.status(400).json({error:'NAME_REQUIRED'});const id=await withTransaction(async conn=>{const [r]=await conn.execute('INSERT INTO parties(company_id,party_type,name,national_id,mobile) VALUES (?,?,?,?,?)',[req.user.companyId,partyType,name,nationalId,mobile]);for(const role of roles)await conn.execute('INSERT IGNORE INTO party_roles(party_id,role_code) VALUES (?,?)',[r.insertId,role]);if(roles.includes('CUSTOMER'))await conn.execute('INSERT IGNORE INTO customer_profiles(party_id,credit_limit,payment_terms_days) VALUES (?,0,0)',[r.insertId]);return r.insertId});await audit(req,'CREATE','party',id,null,req.body);res.status(201).json({id})});
app.get('/api/products',async(req,res)=>{const q=`%${String(req.query.q||'').trim()}%`;const [rows]=await pool.execute(`SELECT p.*,COALESCE(SUM(ib.on_hand_qty),0) on_hand_qty,COALESCE(SUM(ib.reserved_qty),0) reserved_qty FROM products p LEFT JOIN inventory_balances ib ON ib.product_id=p.id AND ib.company_id=p.company_id WHERE p.company_id=? AND p.is_deleted=0 AND (p.name LIKE ? OR p.sku LIKE ? OR p.barcode LIKE ?) GROUP BY p.id ORDER BY p.id DESC LIMIT 200`,[req.user.companyId,q,q,q]);res.json(rows)});
app.post('/api/products',requireRole('WAREHOUSE_MANAGER','SALES_MANAGER'),async(req,res)=>{const {sku,name,unit='عدد',barcode=null,salePrice=0}=req.body||{};if(!sku||!name)return res.status(400).json({error:'SKU_AND_NAME_REQUIRED'});const [r]=await pool.execute('INSERT INTO products(company_id,sku,name,unit,barcode,sale_price) VALUES (?,?,?,?,?,?)',[req.user.companyId,sku,name,unit,barcode,Number(salePrice)]);await audit(req,'CREATE','product',r.insertId,null,req.body);res.status(201).json({id:r.insertId})});
app.get('/api/sales/invoices',async(req,res)=>{const [rows]=await pool.execute(`SELECT si.id,si.invoice_no,si.invoice_date,si.status,si.net_total,si.outstanding_amount,p.name customer FROM sales_invoices si JOIN parties p ON p.id=si.customer_party_id WHERE si.company_id=? AND si.is_void=0 ORDER BY si.id DESC LIMIT 200`,[req.user.companyId]);res.json(rows)});
app.post('/api/sales/invoices',requireRole('SALES_PERSON','SALES_MANAGER'),async(req,res)=>{const {customerPartyId,invoiceDate,lines=[]}=req.body||{};if(!customerPartyId||!Array.isArray(lines)||!lines.length)return res.status(400).json({error:'CUSTOMER_AND_LINES_REQUIRED'});const id=await withTransaction(async conn=>{const [[seq]]=await conn.query('SELECT COALESCE(MAX(id),0)+1 n FROM sales_invoices WHERE company_id=?',[req.user.companyId]);const invoiceNo=`SAL-${new Date().getFullYear()}-${String(seq.n).padStart(6,'0')}`;let gross=0,discount=0,tax=0;for(const l of lines){gross+=Number(l.qty)*Number(l.unitPrice);discount+=Number(l.discount||0);tax+=Number(l.tax||0)}const net=gross-discount+tax;const [r]=await conn.execute(`INSERT INTO sales_invoices(company_id,invoice_no,invoice_date,customer_party_id,status,gross_total,discount_total,tax_total,net_total,outstanding_amount,created_by) VALUES (?,?,?,?,?,?,?,?,?,?,?)`,[req.user.companyId,invoiceNo,invoiceDate||new Date(),customerPartyId,'DRAFT',gross,discount,tax,net,net,Number(req.user.sub)]);for(const l of lines)await conn.execute(`INSERT INTO sales_invoice_lines(invoice_id,product_id,qty,unit_price,discount_amount,tax_amount,line_total) VALUES (?,?,?,?,?,?,?)`,[r.insertId,l.productId,Number(l.qty),Number(l.unitPrice),Number(l.discount||0),Number(l.tax||0),Number(l.qty)*Number(l.unitPrice)-Number(l.discount||0)+Number(l.tax||0)]);return r.insertId});await audit(req,'CREATE','sales_invoice',id,null,req.body);res.status(201).json({id})});
app.post('/api/sales/invoices/:id/post',requireRole('ACCOUNTANT','FINANCE_MANAGER'),async(req,res)=>{const invoiceId=Number(req.params.id);const result=await withTransaction(async conn=>{const [invoices]=await conn.execute('SELECT * FROM sales_invoices WHERE id=? AND company_id=? FOR UPDATE',[invoiceId,req.user.companyId]);const invoice=invoices[0];if(!invoice)throw new Error('INVOICE_NOT_FOUND');if(invoice.status!=='DRAFT'&&invoice.status!=='DELIVERED')throw new Error('INVALID_STATUS_FOR_POSTING');const [mappings]=await conn.execute("SELECT event_code,debit_account_id,credit_account_id FROM accounting_mappings WHERE company_id=? AND event_code='SALES_INVOICE'",[req.user.companyId]);const mapping=mappings[0];if(!mapping)throw new Error('ACCOUNTING_MAPPING_MISSING');const [entry]=await conn.execute(`INSERT INTO journal_entries(company_id,entry_no,entry_date,status,source_type,source_id,description,created_by,posted_at) VALUES (?,CONCAT('JE-',DATE_FORMAT(CURRENT_DATE,'%Y%m%d'),'-',LPAD(?,8,'0')),CURRENT_DATE,'POSTED','SALES_INVOICE',?,?,?,NOW())`,[req.user.companyId,invoiceId,invoiceId,`فاکتور فروش ${invoice.invoice_no}`,Number(req.user.sub)]);await conn.execute(`INSERT INTO journal_lines(journal_entry_id,account_id,party_id,debit,credit,description) VALUES (?,?,?,?,0,?),(?,?,NULL,0,?,?)`,[entry.insertId,mapping.debit_account_id,invoice.customer_party_id,invoice.net_total,`مطالبات ${invoice.invoice_no}`,entry.insertId,mapping.credit_account_id,invoice.net_total,`فروش ${invoice.invoice_no}`]);await conn.execute("UPDATE sales_invoices SET status='OUTSTANDING',posted_at=NOW() WHERE id=?",[invoiceId]);return{journalEntryId:entry.insertId}});await audit(req,'POST','sales_invoice',invoiceId,null,result);res.json({ok:true,...result})});
app.get('/api/tasks',async(req,res)=>{const [rows]=await pool.execute('SELECT * FROM tasks WHERE company_id=? ORDER BY due_at IS NULL,due_at,id DESC LIMIT 200',[req.user.companyId]);res.json(rows)});
app.post('/api/tasks',async(req,res)=>{const {title,description=null,priority='NORMAL',dueAt=null,assignedTo=null}=req.body||{};if(!title)return res.status(400).json({error:'TITLE_REQUIRED'});const [r]=await pool.execute(`INSERT INTO tasks(company_id,title,description,status,priority,due_at,assigned_to,created_by) VALUES (?,?,?,'NEW',?,?,?,?)`,[req.user.companyId,title,description,priority,dueAt,assignedTo,Number(req.user.sub)]);await audit(req,'CREATE','task',r.insertId,null,req.body);res.status(201).json({id:r.insertId})});
app.get('/api/logistics/trips',async(req,res)=>{const [rows]=await pool.execute(`SELECT t.*,v.plate_no,r.name route_name,u.full_name driver_name FROM trips t LEFT JOIN vehicles v ON v.id=t.vehicle_id LEFT JOIN routes r ON r.id=t.route_id LEFT JOIN users u ON u.id=t.driver_user_id WHERE t.company_id=? ORDER BY t.trip_date DESC,t.id DESC LIMIT 200`,[req.user.companyId]);res.json(rows)});
app.post('/api/commissions/calculate',requireRole('SALES_MANAGER','FINANCE_MANAGER'),async(req,res)=>res.json(calculateCommission(req.body||{})));
app.get('/api/finance/trial-balance',requireRole('ACCOUNTANT','FINANCE_MANAGER'),async(req,res)=>{const [rows]=await pool.execute(`SELECT a.code,a.title,COALESCE(SUM(CASE WHEN je.status='POSTED' THEN jl.debit ELSE 0 END),0) debit,COALESCE(SUM(CASE WHEN je.status='POSTED' THEN jl.credit ELSE 0 END),0) credit,COALESCE(SUM(CASE WHEN je.status='POSTED' THEN jl.debit-jl.credit ELSE 0 END),0) balance FROM accounts a LEFT JOIN journal_lines jl ON jl.account_id=a.id LEFT JOIN journal_entries je ON je.id=jl.journal_entry_id WHERE a.company_id=? GROUP BY a.id ORDER BY a.code`,[req.user.companyId]);res.json(rows)});

app.use('/api',(req,res)=>res.status(404).json({error:'API_NOT_FOUND',path:req.path}));
app.use(express.static(webDir,{index:'index.html',maxAge:process.env.NODE_ENV==='production'?'1h':0}));
app.use((_req,res)=>res.sendFile(path.join(webDir,'index.html')));
const port=Number(process.env.PORT||8080);
try{await migrate();await bootstrapAdmin();app.listen(port,'0.0.0.0',()=>console.log(`Tarazpad ERP listening on ${port}`))}catch(error){console.error('Tarazpad failed to start:',error);process.exit(1)}
