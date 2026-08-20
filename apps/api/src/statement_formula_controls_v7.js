import { pool } from './db.js';
import { requireRole } from './auth.js';

const txt=v=>String(v??'').trim();
const n=v=>Number(v||0);
const fail=(message,status=400,details=null)=>{const e=new Error(message);e.status=status;e.details=details;throw e};
const wrap=fn=>async(req,res)=>{try{await fn(req,res)}catch(e){console.error('statement formula control v7',e);res.status(e.status||400).json({error:e.message,details:e.details||undefined})}};

function parseFormula(expression){
  const src=txt(expression);
  if(!src)return {tokens:[],identifiers:[]};
  const tokens=[]; let i=0;
  while(i<src.length){
    if(/\s/.test(src[i])){i++;continue}
    const m=src.slice(i).match(/^([A-Za-z][A-Za-z0-9_]*|\d+(?:\.\d+)?|[()+\-*/])/);
    if(!m)fail('فرمول شامل عبارت یا کاراکتر غیرمجاز است.',422,{position:i,expression:src});
    tokens.push(m[1]); i+=m[1].length;
  }
  if(!tokens.length)fail('فرمول خالی است.',422);
  let depth=0,expectValue=true;
  for(let k=0;k<tokens.length;k++){
    const t=tokens[k],isId=/^[A-Za-z]/.test(t),isNum=/^\d/.test(t);
    if(expectValue){
      if(t==='-'){ continue; }
      if(t==='('){depth++;continue}
      if(isId||isNum){expectValue=false;continue}
      fail('ساختار فرمول معتبر نیست؛ مقدار یا پرانتز باز انتظار می‌رفت.',422,{token:t,index:k});
    }else{
      if(t===')'){depth--;if(depth<0)fail('پرانتز بسته اضافی در فرمول وجود دارد.',422);continue}
      if(['+','-','*','/'].includes(t)){expectValue=true;continue}
      fail('ساختار فرمول معتبر نیست؛ عملگر یا پرانتز بسته انتظار می‌رفت.',422,{token:t,index:k});
    }
  }
  if(depth!==0)fail('پرانتزهای فرمول متوازن نیستند.',422);
  if(expectValue)fail('فرمول با عملگر ناقص پایان یافته است.',422);
  return {tokens,identifiers:[...new Set(tokens.filter(t=>/^[A-Za-z]/.test(t)))]};
}

async function templateContext(templateId,companyId){
  const [t]=await pool.execute('SELECT * FROM financial_statement_templates WHERE id=? AND company_id=?',[templateId,companyId]);
  if(!t.length)fail('قالب صورت مالی پیدا نشد.',404);
  const [lines]=await pool.execute('SELECT id,line_code,line_type,formula_text,parent_id FROM financial_statement_lines WHERE template_id=? ORDER BY id',[templateId]);
  return {template:t[0],lines};
}

function assertFormulaGraph(lines,proposal){
  const graph=new Map();
  const codes=new Set(lines.map(x=>String(x.line_code)));
  if(proposal?.lineCode)codes.add(String(proposal.lineCode));
  const merged=lines.map(x=>proposal?.id&&Number(x.id)===Number(proposal.id)?{...x,line_code:proposal.lineCode||x.line_code,formula_text:proposal.formulaText}:x);
  if(proposal&&!proposal.id)merged.push({id:-1,line_code:proposal.lineCode,formula_text:proposal.formulaText,line_type:proposal.lineType});
  for(const l of merged){
    const code=String(l.line_code),parsed=l.formula_text?parseFormula(l.formula_text):{identifiers:[]};
    for(const ref of parsed.identifiers)if(!codes.has(ref))fail(`کد سطر «${ref}» در همین قالب وجود ندارد.`,422,{lineCode:code,reference:ref});
    if(parsed.identifiers.includes(code))fail(`سطر «${code}» نمی‌تواند مستقیماً به خودش ارجاع دهد.`,422);
    graph.set(code,parsed.identifiers);
  }
  const visiting=new Set(),done=new Set(),stack=[];
  function dfs(code){
    if(done.has(code))return;
    if(visiting.has(code)){const from=stack.indexOf(code),cycle=[...stack.slice(from),code];fail('چرخه فرمولی در صورت مالی مجاز نیست.',422,{cycle})}
    visiting.add(code);stack.push(code);
    for(const ref of graph.get(code)||[])dfs(ref);
    stack.pop();visiting.delete(code);done.add(code);
  }
  for(const code of graph.keys())dfs(code);
}

export function registerStatementFormulaControlsV7(app){
  app.post('/api/iran/finance/statement-templates/:id/lines',requireRole('FINANCE_MANAGER'),wrap(async(req,res)=>{
    const templateId=Number(req.params.id),b=req.body||{},ctx=await templateContext(templateId,req.user.companyId);
    if(ctx.template.is_system)fail('ساختار قالب سیستمی قفل است؛ ابتدا یک نسخه قابل ویرایش ایجاد کنید.',409);
    const lineCode=txt(b.lineCode),title=txt(b.title),lineType=b.lineType||'ACCOUNT_SUM',formulaText=txt(b.formulaText)||null;
    if(!lineCode||!title)fail('کد و عنوان سطر الزامی است.');
    if(!/^[A-Za-z][A-Za-z0-9_]*$/.test(lineCode))fail('کد سطر فقط باید شامل حروف لاتین، عدد و زیرخط باشد و با حرف شروع شود.',422);
    if(ctx.lines.some(x=>String(x.line_code)===lineCode))fail('کد سطر در این قالب تکراری است.',409);
    if(['FORMULA','SUBTOTAL','TOTAL'].includes(lineType)&&!formulaText)fail('برای سطر محاسباتی، فرمول الزامی است.',422);
    if(formulaText)parseFormula(formulaText);
    assertFormulaGraph(ctx.lines,{lineCode,lineType,formulaText});
    if(b.parentId&&!ctx.lines.some(x=>Number(x.id)===Number(b.parentId)))fail('سطر والد متعلق به این قالب نیست.',422);
    const [r]=await pool.execute(`INSERT INTO financial_statement_lines(template_id,parent_id,line_code,title_fa,line_type,normal_sign,formula_text,sort_order,display_level,is_bold) VALUES (?,?,?,?,?,?,?,?,?,?)`,[templateId,b.parentId||null,lineCode,title,lineType,b.normalSign||'AUTO',formulaText,n(b.sortOrder),n(b.displayLevel)||1,b.isBold?1:0]);
    res.status(201).json({id:r.insertId});
  }));

  app.put('/api/iran/finance/statement-lines/:id',requireRole('FINANCE_MANAGER'),wrap(async(req,res)=>{
    const id=Number(req.params.id),[row]=await pool.execute(`SELECT l.*,t.company_id,t.is_system FROM financial_statement_lines l JOIN financial_statement_templates t ON t.id=l.template_id WHERE l.id=? AND t.company_id=?`,[id,req.user.companyId]);
    if(!row.length)fail('سطر صورت مالی پیدا نشد.',404);
    if(row[0].is_system)fail('ساختار قالب سیستمی قفل است؛ ابتدا Clone ایجاد کنید.',409);
    const current=row[0],ctx=await templateContext(current.template_id,req.user.companyId),b=req.body||{};
    const lineCode=txt(b.lineCode)||current.line_code,title=txt(b.title)||current.title_fa,lineType=b.lineType||current.line_type,formulaText=b.formulaText===undefined?current.formula_text:(txt(b.formulaText)||null);
    if(!/^[A-Za-z][A-Za-z0-9_]*$/.test(lineCode))fail('کد سطر معتبر نیست.',422);
    if(ctx.lines.some(x=>Number(x.id)!==id&&String(x.line_code)===lineCode))fail('کد سطر در این قالب تکراری است.',409);
    if(['FORMULA','SUBTOTAL','TOTAL'].includes(lineType)&&!formulaText)fail('برای سطر محاسباتی، فرمول الزامی است.',422);
    if(formulaText)parseFormula(formulaText);
    assertFormulaGraph(ctx.lines,{id,lineCode,lineType,formulaText});
    const parentId=b.parentId===undefined?current.parent_id:(b.parentId||null);
    if(parentId===id)fail('سطر نمی‌تواند والد خودش باشد.',422);
    if(parentId&&!ctx.lines.some(x=>Number(x.id)===Number(parentId)))fail('سطر والد متعلق به همین قالب نیست.',422);
    await pool.execute(`UPDATE financial_statement_lines SET parent_id=?,line_code=?,title_fa=?,line_type=?,normal_sign=?,formula_text=?,sort_order=?,display_level=?,is_bold=? WHERE id=?`,[parentId,lineCode,title,lineType,b.normalSign||current.normal_sign,formulaText,b.sortOrder==null?current.sort_order:n(b.sortOrder),b.displayLevel==null?current.display_level:n(b.displayLevel),b.isBold==null?current.is_bold:(b.isBold?1:0),id]);
    res.json({ok:true});
  }));
}
