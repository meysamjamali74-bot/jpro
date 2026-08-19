from pathlib import Path

ext = Path('apps/api/src/iran_extensions.js')
s = ext.read_text(encoding='utf-8')
imports = """import { registerYearEndCalculateOverrideV7 } from './year_end_calculate_override_v7.js';
import { registerYearEndV7Routes } from './year_end_v7.js';
import { registerStatementDesignerV7Routes } from './statement_designer_v7.js';
import { registerComplianceV7Routes } from './compliance_v7.js';
"""
if "registerYearEndV7Routes" not in s:
    s = imports + s
anchor = "  app.use(fieldPolicyMiddleware);\n"
registrations = """

  // Enterprise 1.7: year-end, financial statement designer and statutory compliance.
  registerYearEndCalculateOverrideV7(app);
  registerYearEndV7Routes(app);
  registerStatementDesignerV7Routes(app);
  registerComplianceV7Routes(app);
"""
if "registerYearEndCalculateOverrideV7(app)" not in s:
    if anchor not in s:
        raise SystemExit('fieldPolicyMiddleware anchor not found')
    s = s.replace(anchor, anchor + registrations, 1)
ext.write_text(s, encoding='utf-8')

fa = Path('apps/web/fa-overlay.js')
f = fa.read_text(encoding='utf-8')
if "phase17-ui.js" not in f:
    if "load('/phase16-ui.js');" in f:
        f = f.replace("load('/phase16-ui.js');", "load('/phase16-ui.js');load('/phase17-ui.js');", 1)
    else:
        f = f.replace('})();', "load('/phase17-ui.js');})();", 1)
fa.write_text(f, encoding='utf-8')

print('Enterprise 1.7 wiring complete')
