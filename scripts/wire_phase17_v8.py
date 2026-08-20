from pathlib import Path
p=Path('apps/api/src/iran_extensions.js');s=p.read_text(encoding='utf-8')
required=[
 ('registerFinanceReportsFinalV7','./finance_reports_final_v7.js'),
 ('registerYearEndFinalV7','./year_end_final_v7.js'),
 ('registerYearEndV7Routes','./year_end_v7.js'),
 ('registerStatementDesignerV7Routes','./statement_designer_v7.js'),
 ('registerComplianceFinalV7','./compliance_final_v7.js'),
 ('registerComplianceV7Routes','./compliance_v7.js'),
]
all_phase17={
 'registerFinanceReportsFinalV7','registerStatementRenderUnifiedV7','registerFiscalScopeReportingOverrideV7','registerHistoricalReportingOverrideV7','registerStatementRenderOverrideV7',
 'registerYearEndCalculateOverrideV7','registerYearEndOpeningOverrideV7','registerYearEndFinalV7','registerYearEndV7Routes','registerStatementDesignerV7Routes',
 'registerComplianceControlOverrideV7','registerComplianceFinalV7','registerComplianceV7Routes'
}
for name,src in reversed(required):
    imp=f"import {{ {name} }} from '{src}';\n"
    if imp not in s:s=imp+s
out=[]
for line in s.splitlines(True):
    if any(line.strip()==f'{name}(app);' for name in all_phase17):continue
    out.append(line)
s=''.join(out);anchor='  app.use(fieldPolicyMiddleware);\n'
if anchor not in s:raise SystemExit('fieldPolicyMiddleware anchor missing')
block='\n  // Enterprise 1.7 authoritative route owners.\n'+''.join(f'  {name}(app);\n' for name,_ in required)
s=s.replace(anchor,anchor+block,1);p.write_text(s,encoding='utf-8')
fa=Path('apps/web/fa-overlay.js');f=fa.read_text(encoding='utf-8')
if "phase17-ui.js" not in f:f=f.replace("load('/phase16-ui.js');","load('/phase16-ui.js');load('/phase17-ui.js');",1)
fa.write_text(f,encoding='utf-8')
