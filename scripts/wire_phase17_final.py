from pathlib import Path

ext=Path('apps/api/src/iran_extensions.js')
s=ext.read_text(encoding='utf-8')
modules=[
 ('registerFiscalScopeReportingOverrideV7','./fiscal_scope_reporting_override_v7.js'),
 ('registerHistoricalReportingOverrideV7','./historical_reporting_override_v7.js'),
 ('registerStatementRenderOverrideV7','./statement_render_override_v7.js'),
 ('registerYearEndCalculateOverrideV7','./year_end_calculate_override_v7.js'),
 ('registerYearEndV7Routes','./year_end_v7.js'),
 ('registerStatementDesignerV7Routes','./statement_designer_v7.js'),
 ('registerComplianceV7Routes','./compliance_v7.js'),
]
for name,src in reversed(modules):
    imp=f"import {{ {name} }} from '{src}';\n"
    if imp not in s:
        s=imp+s
# Remove registrations inserted by earlier idempotent wiring jobs, then insert once in deterministic order.
lines=[]
names={x[0] for x in modules}
for line in s.splitlines(True):
    stripped=line.strip()
    if any(stripped==f'{name}(app);' for name in names):
        continue
    lines.append(line)
s=''.join(lines)
anchor='  app.use(fieldPolicyMiddleware);\n'
if anchor not in s:
    raise SystemExit('fieldPolicyMiddleware anchor not found')
block='\n  // Enterprise 1.7 deterministic control order.\n'+''.join(f'  {name}(app);\n' for name,_ in modules)
s=s.replace(anchor,anchor+block,1)
ext.write_text(s,encoding='utf-8')

fa=Path('apps/web/fa-overlay.js')
f=fa.read_text(encoding='utf-8')
if "phase17-ui.js" not in f:
    if "load('/phase16-ui.js');" in f:
        f=f.replace("load('/phase16-ui.js');", "load('/phase16-ui.js');load('/phase17-ui.js');",1)
    else:
        f=f.replace('})();',"load('/phase17-ui.js');})();",1)
fa.write_text(f,encoding='utf-8')
print('Enterprise 1.7 final wiring complete')
