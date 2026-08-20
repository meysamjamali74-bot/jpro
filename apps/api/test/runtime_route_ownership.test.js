import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here=path.dirname(fileURLToPath(import.meta.url));
const runtime=fs.readFileSync(path.resolve(here,'../src/iran_extensions.js'),'utf8');

const authoritative=[
  'registerFinanceReportsFinalV7',
  'registerYearEndFinalV7',
  'registerYearEndV7Routes',
  'registerStatementFormulaControlsV7',
  'registerStatementDesignerV7Routes',
  'registerComplianceFinalV7',
  'registerComplianceV7Routes',
];

const superseded=[
  'registerStatementRenderUnifiedV7',
  'registerFiscalScopeReportingOverrideV7',
  'registerHistoricalReportingOverrideV7',
  'registerStatementRenderOverrideV7',
  'registerYearEndCalculateOverrideV7',
  'registerYearEndOpeningOverrideV7',
  'registerComplianceControlOverrideV7',
];

function callCount(name){
  return (runtime.match(new RegExp(`\\b${name}\\(app\\);`,'g'))||[]).length;
}
function importCount(name){
  return (runtime.match(new RegExp(`import\\s*\\{[^}]*\\b${name}\\b[^}]*\\}`,'g'))||[]).length;
}

test('each authoritative Enterprise 1.7 route owner is registered exactly once',()=>{
  for(const name of authoritative){
    assert.equal(callCount(name),1,`${name} must be registered exactly once`);
    assert.equal(importCount(name),1,`${name} must be imported exactly once`);
  }
});

test('superseded Phase 1.7 route owners are not registered at runtime',()=>{
  for(const name of superseded) assert.equal(callCount(name),0,`${name} is superseded and must not own runtime routes`);
});

test('authoritative ordering protects final reporting and control endpoints',()=>{
  const idx=name=>runtime.indexOf(`${name}(app);`);
  assert.ok(idx('registerFinanceReportsFinalV7')<idx('registerYearEndFinalV7'));
  assert.ok(idx('registerYearEndFinalV7')<idx('registerYearEndV7Routes'));
  assert.ok(idx('registerStatementFormulaControlsV7')<idx('registerStatementDesignerV7Routes'));
  assert.ok(idx('registerComplianceFinalV7')<idx('registerComplianceV7Routes'));
});
