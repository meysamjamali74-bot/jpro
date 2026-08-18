INSERT IGNORE INTO accounting_rule_lines(company_id,event_code,line_role,amount_source,account_id,party_source,priority,is_active)
SELECT c.id,'PURCHASE_INVOICE_GOODS_NONOFFICIAL_IR','DEBIT','NET_BEFORE_TAX',grni.id,NULL,10,1 FROM companies c JOIN accounts grni ON grni.company_id=c.id AND grni.code='210150';
INSERT IGNORE INTO accounting_rule_lines(company_id,event_code,line_role,amount_source,account_id,party_source,priority,is_active)
SELECT c.id,'PURCHASE_INVOICE_GOODS_NONOFFICIAL_IR','DEBIT','VAT_TOTAL',inv.id,NULL,20,1 FROM companies c JOIN accounts inv ON inv.company_id=c.id AND inv.code='130100';
INSERT IGNORE INTO accounting_rule_lines(company_id,event_code,line_role,amount_source,account_id,party_source,priority,is_active)
SELECT c.id,'PURCHASE_INVOICE_GOODS_NONOFFICIAL_IR','CREDIT','NET_TOTAL',ap.id,'SUPPLIER',30,1 FROM companies c JOIN accounts ap ON ap.company_id=c.id AND ap.code='210100';
INSERT IGNORE INTO accounting_rule_lines(company_id,event_code,line_role,amount_source,account_id,party_source,priority,is_active)
SELECT c.id,'PURCHASE_INVOICE_SERVICE_NONOFFICIAL_IR','DEBIT','NET_TOTAL',exp.id,NULL,10,1 FROM companies c JOIN accounts exp ON exp.company_id=c.id AND exp.code='610200';
INSERT IGNORE INTO accounting_rule_lines(company_id,event_code,line_role,amount_source,account_id,party_source,priority,is_active)
SELECT c.id,'PURCHASE_INVOICE_SERVICE_NONOFFICIAL_IR','CREDIT','NET_TOTAL',ap.id,'SUPPLIER',20,1 FROM companies c JOIN accounts ap ON ap.company_id=c.id AND ap.code='210100';