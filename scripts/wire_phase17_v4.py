from pathlib import Path
p=Path('apps/api/src/iran_extensions.js');s=p.read_text(encoding='utf-8')
mods=[
 ('registerStatementRenderUnifiedV7','./statement_render_unified_v7.js'),
 ('registerFiscalScopeReportingOverrideV7','./fiscal_scope_reporting_override_v7.js'),
 ('registerHistoricalReportingOverrideV7','./historical_reporting_override_v7.js'),
 ('registerStatementRenderOverrideV7','./statement_render_override_v7.js'),
 ('registerYearEndCalculateOverrideV7','./year_end_calculate_override_v7.js'),
 ('registerYearEndOpeningOverrideV7','./year_end_opening_override_v7.js'),
 ('registerYearEndV7Routes','./year_end_v7.js'),
 ('registerStatementDesignerV7Routes','./statement_designer_v7.js'),
 ('registerComplianceControlOverrideV7','./compliance_control_override_v7.js'),
 ('registerComplianceV7Routes','./compliance_v7.js'),
]
for name,src in reversed(mods):
    imp=f"import {{ {name} }} from '{src}';\n"
    if imp not in s:s=imp+s
names={x[0] for x in mods};out=[]
for line in s.splitlines(True):
    if any(line.strip()==f'{name}(app);' for name in names):continue
    out.append(line)
s=''.join(out);anchor='  app.use(fieldPolicyMiddleware);\n'
if anchor not in s:raise SystemExit('middleware anchor missing')
block='\n  // Enterprise 1.7 final control order with compliance source integrity.\n'+''.join(f'  {name}(app);\n' for name,_ in mods)
s=s.replace(anchor,anchor+block,1);p.write_text(s,encoding='utf-8')
fa=Path('apps/web/fa-overlay.js');f=fa.read_text(encoding='utf-8')
if "phase17-ui.js" not in f:f=f.replace("load('/phase16-ui.js');","load('/phase16-ui.js');load('/phase17-ui.js');",1)
fa.write_text(f,encoding='utf-8')
