INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'210350','سایر عوارض و وجوه قانونی پرداختنی',3,'CREDIT','LIABILITY',1 FROM companies;

INSERT IGNORE INTO accounting_rule_lines(company_id,event_code,line_role,amount_source,account_id,party_source,priority,is_active)
SELECT c.id,'SALES_INVOICE_IR','CREDIT','OTHER_DUTIES',a.id,NULL,35,1
FROM companies c JOIN accounts a ON a.company_id=c.id AND a.code='210350';