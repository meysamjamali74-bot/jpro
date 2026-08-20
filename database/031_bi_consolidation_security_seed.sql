ALTER TABLE consolidation_runs
  ADD COLUMN reviewed_by BIGINT UNSIGNED NULL,
  ADD COLUMN finalized_by BIGINT UNSIGNED NULL,
  ADD COLUMN reviewed_at DATETIME NULL,
  ADD COLUMN finalized_at DATETIME NULL,
  ADD COLUMN intercompany_difference DECIMAL(20,2) NOT NULL DEFAULT 0,
  ADD CONSTRAINT fk_cons_reviewer FOREIGN KEY(reviewed_by) REFERENCES users(id),
  ADD CONSTRAINT fk_cons_finalizer FOREIGN KEY(finalized_by) REFERENCES users(id);

INSERT IGNORE INTO semantic_models(company_id,code,title_fa,domain_code,base_source,grain_description,created_by)
SELECT c.id,'FINANCE_GL','مدل معنایی دفترکل','FINANCE','journal_lines','هر ردیف سند حسابداری در سطح حساب، شخص، مرکز هزینه و پروژه',MIN(u.id)
FROM companies c JOIN users u ON u.company_id=c.id GROUP BY c.id;
INSERT IGNORE INTO semantic_models(company_id,code,title_fa,domain_code,base_source,grain_description,created_by)
SELECT c.id,'SALES_INVOICE','مدل معنایی فروش','SALES','sales_invoice_lines','هر ردیف فاکتور فروش با مشتری، کالا، فروش و سود ناخالص',MIN(u.id)
FROM companies c JOIN users u ON u.company_id=c.id GROUP BY c.id;
INSERT IGNORE INTO semantic_models(company_id,code,title_fa,domain_code,base_source,grain_description,created_by)
SELECT c.id,'INVENTORY_POSITION','مدل معنایی موجودی','INVENTORY','inventory_balances','موجودی هر کالا در هر انبار، بچ و تاریخ انقضا',MIN(u.id)
FROM companies c JOIN users u ON u.company_id=c.id GROUP BY c.id;

INSERT IGNORE INTO kpi_definitions(company_id,code,title_fa,domain_code,formula_json,target_json,thresholds_json,owner_role_code,effective_from,created_by)
SELECT c.id,'NET_SALES','فروش خالص','SALES',JSON_OBJECT('engine','BUILTIN','code','NET_SALES'),NULL,NULL,'SALES_MANAGER','2026-03-21',MIN(u.id) FROM companies c JOIN users u ON u.company_id=c.id GROUP BY c.id;
INSERT IGNORE INTO kpi_definitions(company_id,code,title_fa,domain_code,formula_json,target_json,thresholds_json,owner_role_code,effective_from,created_by)
SELECT c.id,'GROSS_PROFIT','سود ناخالص','FINANCE',JSON_OBJECT('engine','BUILTIN','code','GROSS_PROFIT'),NULL,NULL,'FINANCE_MANAGER','2026-03-21',MIN(u.id) FROM companies c JOIN users u ON u.company_id=c.id GROUP BY c.id;
INSERT IGNORE INTO kpi_definitions(company_id,code,title_fa,domain_code,formula_json,target_json,thresholds_json,owner_role_code,effective_from,created_by)
SELECT c.id,'GROSS_MARGIN','حاشیه سود ناخالص','FINANCE',JSON_OBJECT('engine','BUILTIN','code','GROSS_MARGIN'),NULL,JSON_OBJECT('warning_below',10),'FINANCE_MANAGER','2026-03-21',MIN(u.id) FROM companies c JOIN users u ON u.company_id=c.id GROUP BY c.id;
INSERT IGNORE INTO kpi_definitions(company_id,code,title_fa,domain_code,formula_json,target_json,thresholds_json,owner_role_code,effective_from,created_by)
SELECT c.id,'AR_BALANCE','مانده حساب‌های دریافتنی','FINANCE',JSON_OBJECT('engine','BUILTIN','code','AR_BALANCE'),NULL,NULL,'FINANCE_MANAGER','2026-03-21',MIN(u.id) FROM companies c JOIN users u ON u.company_id=c.id GROUP BY c.id;
INSERT IGNORE INTO kpi_definitions(company_id,code,title_fa,domain_code,formula_json,target_json,thresholds_json,owner_role_code,effective_from,created_by)
SELECT c.id,'AP_BALANCE','مانده حساب‌های پرداختنی','FINANCE',JSON_OBJECT('engine','BUILTIN','code','AP_BALANCE'),NULL,NULL,'FINANCE_MANAGER','2026-03-21',MIN(u.id) FROM companies c JOIN users u ON u.company_id=c.id GROUP BY c.id;
INSERT IGNORE INTO kpi_definitions(company_id,code,title_fa,domain_code,formula_json,target_json,thresholds_json,owner_role_code,effective_from,created_by)
SELECT c.id,'OVERDUE_AR','مطالبات سررسید گذشته','FINANCE',JSON_OBJECT('engine','BUILTIN','code','OVERDUE_AR'),NULL,JSON_OBJECT('warning_above',0),'FINANCE_MANAGER','2026-03-21',MIN(u.id) FROM companies c JOIN users u ON u.company_id=c.id GROUP BY c.id;
INSERT IGNORE INTO kpi_definitions(company_id,code,title_fa,domain_code,formula_json,target_json,thresholds_json,owner_role_code,effective_from,created_by)
SELECT c.id,'CASH_POSITION','مانده نقد و بانک','TREASURY',JSON_OBJECT('engine','BUILTIN','code','CASH_POSITION'),NULL,NULL,'FINANCE_MANAGER','2026-03-21',MIN(u.id) FROM companies c JOIN users u ON u.company_id=c.id GROUP BY c.id;
INSERT IGNORE INTO kpi_definitions(company_id,code,title_fa,domain_code,formula_json,target_json,thresholds_json,owner_role_code,effective_from,created_by)
SELECT c.id,'INVENTORY_VALUE','ارزش موجودی','INVENTORY',JSON_OBJECT('engine','BUILTIN','code','INVENTORY_VALUE'),NULL,NULL,'WAREHOUSE_MANAGER','2026-03-21',MIN(u.id) FROM companies c JOIN users u ON u.company_id=c.id GROUP BY c.id;
INSERT IGNORE INTO kpi_definitions(company_id,code,title_fa,domain_code,formula_json,target_json,thresholds_json,owner_role_code,effective_from,created_by)
SELECT c.id,'DELIVERY_RATE','نرخ تحویل موفق','LOGISTICS',JSON_OBJECT('engine','BUILTIN','code','DELIVERY_RATE'),JSON_OBJECT('target',95),JSON_OBJECT('warning_below',90),'LOGISTICS_MANAGER','2026-03-21',MIN(u.id) FROM companies c JOIN users u ON u.company_id=c.id GROUP BY c.id;
INSERT IGNORE INTO kpi_definitions(company_id,code,title_fa,domain_code,formula_json,target_json,thresholds_json,owner_role_code,effective_from,created_by)
SELECT c.id,'HEADCOUNT','تعداد پرسنل فعال','HR',JSON_OBJECT('engine','BUILTIN','code','HEADCOUNT'),NULL,NULL,'HR_MANAGER','2026-03-21',MIN(u.id) FROM companies c JOIN users u ON u.company_id=c.id GROUP BY c.id;
INSERT IGNORE INTO kpi_definitions(company_id,code,title_fa,domain_code,formula_json,target_json,thresholds_json,owner_role_code,effective_from,created_by)
SELECT c.id,'PAYROLL_NET','خالص حقوق دوره','HR',JSON_OBJECT('engine','BUILTIN','code','PAYROLL_NET'),NULL,NULL,'HR_MANAGER','2026-03-21',MIN(u.id) FROM companies c JOIN users u ON u.company_id=c.id GROUP BY c.id;

INSERT IGNORE INTO segregation_of_duties_rules(company_id,code,title_fa,role_a,role_b,severity,action,is_active)
SELECT id,'SOD_SALES_FINANCE','تفکیک فروشنده از تأیید مالی','SALES_PERSON','FINANCE_MANAGER','CRITICAL','BLOCK',1 FROM companies;
INSERT IGNORE INTO segregation_of_duties_rules(company_id,code,title_fa,role_a,role_b,severity,action,is_active)
SELECT id,'SOD_WAREHOUSE_FINANCE','تفکیک انبار از تأیید مالی','WAREHOUSE_MANAGER','FINANCE_MANAGER','HIGH','WARN',1 FROM companies;
INSERT IGNORE INTO segregation_of_duties_rules(company_id,code,title_fa,role_a,role_b,severity,action,is_active)
SELECT id,'SOD_ACCOUNTING_APPROVAL','تفکیک تهیه سند از تأیید نهایی','ACCOUNTANT','FINANCE_MANAGER','HIGH','WARN',1 FROM companies;
