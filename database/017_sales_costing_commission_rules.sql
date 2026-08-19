INSERT IGNORE INTO accounting_rule_lines(company_id,event_code,line_role,amount_source,account_id,party_source,priority,is_active)
SELECT c.id,'SALES_INVOICE_IR','DEBIT','COGS_TOTAL',cogs.id,NULL,40,1
FROM companies c JOIN accounts cogs ON cogs.company_id=c.id AND cogs.code='510100';

INSERT IGNORE INTO accounting_rule_lines(company_id,event_code,line_role,amount_source,account_id,party_source,priority,is_active)
SELECT c.id,'SALES_INVOICE_IR','CREDIT','COGS_TOTAL',inv.id,NULL,50,1
FROM companies c JOIN accounts inv ON inv.company_id=c.id AND inv.code='130100';