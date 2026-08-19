from pathlib import Path
p=Path('apps/api/src/iran_extensions.js')
s=p.read_text(encoding='utf-8')
imports="""import { registerHistoricalReportingOverrideV7 } from './historical_reporting_override_v7.js';
import { registerStatementRenderOverrideV7 } from './statement_render_override_v7.js';
"""
if 'registerHistoricalReportingOverrideV7' not in s:
    s=imports+s
anchor='  app.use(fieldPolicyMiddleware);\n'
regs="""

  // Historical performance statements must exclude system year-end closing entries.
  registerHistoricalReportingOverrideV7(app);
  registerStatementRenderOverrideV7(app);
"""
if 'registerHistoricalReportingOverrideV7(app)' not in s:
    if anchor not in s: raise SystemExit('middleware anchor not found')
    s=s.replace(anchor,anchor+regs,1)
p.write_text(s,encoding='utf-8')
print('Phase17 reporting overrides wired')
