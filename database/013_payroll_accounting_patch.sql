ALTER TABLE payroll_legal_parameters ADD COLUMN jalali_year SMALLINT NULL AFTER title;
UPDATE payroll_legal_parameters SET jalali_year=1405 WHERE effective_from='2026-03-21' AND effective_to='2027-03-20' AND jalali_year IS NULL;

UPDATE payroll_legal_parameters
SET parameters_json=JSON_SET(parameters_json,'$.insurance_daily_cap_multiplier',7,'$.calculation_mode','MONTHLY_EFFECTIVE_DATED')
WHERE jalali_year=1405;

INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'110500','مطالبات کارکنان و وام پرسنلی',3,'DEBIT','ASSET',1 FROM companies;

INSERT IGNORE INTO accounting_rule_lines(company_id,event_code,line_role,amount_source,account_id,party_source,priority,is_active)
SELECT c.id,'PAYROLL_IR','CREDIT','LOAN_DEDUCTION',loan.id,NULL,45,1 FROM companies c JOIN accounts loan ON loan.company_id=c.id AND loan.code='110500';