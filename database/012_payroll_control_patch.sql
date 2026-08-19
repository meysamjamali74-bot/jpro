INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'220400','سایر کسورات حقوق پرداختنی',3,'CREDIT','LIABILITY',1 FROM companies;

DELETE arl FROM accounting_rule_lines arl JOIN accounts a ON a.id=arl.account_id
WHERE arl.event_code='PAYROLL_IR' AND arl.amount_source='OTHER_DEDUCTIONS' AND a.code='220100';

INSERT IGNORE INTO accounting_rule_lines(company_id,event_code,line_role,amount_source,account_id,party_source,priority,is_active)
SELECT c.id,'PAYROLL_IR','CREDIT','OTHER_DEDUCTIONS',ded.id,NULL,50,1 FROM companies c JOIN accounts ded ON ded.company_id=c.id AND ded.code='220400';

UPDATE payroll_legal_parameters
SET parameters_json=JSON_SET(parameters_json,
 '$.monthly_hours_divisor',220,
 '$.housing_insurable',false,
 '$.food_insurable',false,
 '$.marriage_insurable',false,
 '$.child_insurable',false,
 '$.seniority_insurable',true,
 '$.overtime_insurable',true,
 '$.housing_taxable',true,
 '$.food_taxable',true,
 '$.marriage_taxable',true,
 '$.child_taxable',true,
 '$.seniority_taxable',true,
 '$.overtime_taxable',true)
WHERE effective_from='2026-03-21' AND effective_to='2027-03-20';