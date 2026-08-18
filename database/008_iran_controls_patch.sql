ALTER TABLE employee_profiles ADD COLUMN company_id BIGINT UNSIGNED NULL AFTER party_id;
UPDATE employee_profiles ep JOIN parties p ON p.id=ep.party_id SET ep.company_id=p.company_id WHERE ep.company_id IS NULL;
ALTER TABLE employee_profiles MODIFY company_id BIGINT UNSIGNED NOT NULL, DROP INDEX uq_employee_personnel, ADD UNIQUE KEY uq_employee_personnel(company_id,personnel_no), ADD CONSTRAINT fk_employee_company FOREIGN KEY(company_id) REFERENCES companies(id);

INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'210310','سایر عوارض و وجوه قانونی پرداختنی',3,'CREDIT','LIABILITY',1 FROM companies;

INSERT IGNORE INTO accounting_rule_lines(company_id,event_code,line_role,amount_source,account_id,party_source,priority,is_active)
SELECT c.id,'SALES_INVOICE_IR','CREDIT','OTHER_DUTIES',duties.id,NULL,40,1 FROM companies c JOIN accounts duties ON duties.company_id=c.id AND duties.code='210310';