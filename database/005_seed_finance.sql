INSERT IGNORE INTO companies(code,name,base_currency,timezone,is_active) VALUES ('TRZ','ترازپاد','IRR','Asia/Tehran',1);
INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting) SELECT id,'110100','حساب‌های دریافتنی تجاری',3,'DEBIT','ASSET',1 FROM companies WHERE code='TRZ';
INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting) SELECT id,'130100','موجودی کالا',3,'DEBIT','ASSET',1 FROM companies WHERE code='TRZ';
INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting) SELECT id,'410100','فروش کالا و خدمات',3,'CREDIT','REVENUE',1 FROM companies WHERE code='TRZ';
INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting) SELECT id,'510100','بهای تمام‌شده کالای فروش‌رفته',3,'DEBIT','EXPENSE',1 FROM companies WHERE code='TRZ';
INSERT IGNORE INTO accounting_mappings(company_id,event_code,debit_account_id,credit_account_id)
SELECT c.id,'SALES_INVOICE',ar.id,sales.id FROM companies c JOIN accounts ar ON ar.company_id=c.id AND ar.code='110100' JOIN accounts sales ON sales.company_id=c.id AND sales.code='410100' WHERE c.code='TRZ';