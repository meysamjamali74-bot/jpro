INSERT IGNORE INTO financial_statement_templates(company_id,code,title_fa,statement_type,is_system,is_active)
SELECT id,'STD_PL','صورت سود و زیان استاندارد','PROFIT_LOSS',1,1 FROM companies;
INSERT IGNORE INTO financial_statement_templates(company_id,code,title_fa,statement_type,is_system,is_active)
SELECT id,'STD_BS','صورت وضعیت مالی استاندارد','BALANCE_SHEET',1,1 FROM companies;

INSERT IGNORE INTO financial_statement_lines(template_id,line_code,title_fa,line_type,normal_sign,formula_text,sort_order,display_level,is_bold)
SELECT id,'OPERATING_REVENUE','درآمدهای عملیاتی','ACCOUNT_SUM','CREDIT',NULL,10,1,0 FROM financial_statement_templates WHERE code='STD_PL';
INSERT IGNORE INTO financial_statement_lines(template_id,line_code,title_fa,line_type,normal_sign,formula_text,sort_order,display_level,is_bold)
SELECT id,'COST_OF_SALES','بهای تمام‌شده کالای فروش‌رفته/خدمات','ACCOUNT_SUM','DEBIT',NULL,20,1,0 FROM financial_statement_templates WHERE code='STD_PL';
INSERT IGNORE INTO financial_statement_lines(template_id,line_code,title_fa,line_type,normal_sign,formula_text,sort_order,display_level,is_bold)
SELECT id,'GROSS_PROFIT','سود (زیان) ناخالص','FORMULA','AUTO','OPERATING_REVENUE-COST_OF_SALES',30,1,1 FROM financial_statement_templates WHERE code='STD_PL';
INSERT IGNORE INTO financial_statement_lines(template_id,line_code,title_fa,line_type,normal_sign,formula_text,sort_order,display_level,is_bold)
SELECT id,'OPERATING_EXPENSE','هزینه‌های عملیاتی','ACCOUNT_SUM','DEBIT',NULL,40,1,0 FROM financial_statement_templates WHERE code='STD_PL';
INSERT IGNORE INTO financial_statement_lines(template_id,line_code,title_fa,line_type,normal_sign,formula_text,sort_order,display_level,is_bold)
SELECT id,'OPERATING_PROFIT','سود (زیان) عملیاتی','FORMULA','AUTO','GROSS_PROFIT-OPERATING_EXPENSE',50,1,1 FROM financial_statement_templates WHERE code='STD_PL';
INSERT IGNORE INTO financial_statement_lines(template_id,line_code,title_fa,line_type,normal_sign,formula_text,sort_order,display_level,is_bold)
SELECT id,'OTHER_REVENUE','سایر درآمدها','ACCOUNT_SUM','CREDIT',NULL,60,1,0 FROM financial_statement_templates WHERE code='STD_PL';
INSERT IGNORE INTO financial_statement_lines(template_id,line_code,title_fa,line_type,normal_sign,formula_text,sort_order,display_level,is_bold)
SELECT id,'OTHER_EXPENSE','سایر هزینه‌ها','ACCOUNT_SUM','DEBIT',NULL,70,1,0 FROM financial_statement_templates WHERE code='STD_PL';
INSERT IGNORE INTO financial_statement_lines(template_id,line_code,title_fa,line_type,normal_sign,formula_text,sort_order,display_level,is_bold)
SELECT id,'PROFIT_BEFORE_TAX','سود (زیان) قبل از مالیات','FORMULA','AUTO','OPERATING_PROFIT+OTHER_REVENUE-OTHER_EXPENSE',80,1,1 FROM financial_statement_templates WHERE code='STD_PL';
INSERT IGNORE INTO financial_statement_lines(template_id,line_code,title_fa,line_type,normal_sign,formula_text,sort_order,display_level,is_bold)
SELECT id,'TAX','مالیات بر درآمد','ACCOUNT_SUM','DEBIT',NULL,90,1,0 FROM financial_statement_templates WHERE code='STD_PL';
INSERT IGNORE INTO financial_statement_lines(template_id,line_code,title_fa,line_type,normal_sign,formula_text,sort_order,display_level,is_bold)
SELECT id,'NET_PROFIT','سود (زیان) خالص','FORMULA','AUTO','PROFIT_BEFORE_TAX-TAX',100,1,1 FROM financial_statement_templates WHERE code='STD_PL';

INSERT IGNORE INTO financial_statement_lines(template_id,line_code,title_fa,line_type,normal_sign,formula_text,sort_order,display_level,is_bold)
SELECT id,'CURRENT_ASSET','دارایی‌های جاری','ACCOUNT_SUM','DEBIT',NULL,10,1,0 FROM financial_statement_templates WHERE code='STD_BS';
INSERT IGNORE INTO financial_statement_lines(template_id,line_code,title_fa,line_type,normal_sign,formula_text,sort_order,display_level,is_bold)
SELECT id,'NONCURRENT_ASSET','دارایی‌های غیرجاری','ACCOUNT_SUM','DEBIT',NULL,20,1,0 FROM financial_statement_templates WHERE code='STD_BS';
INSERT IGNORE INTO financial_statement_lines(template_id,line_code,title_fa,line_type,normal_sign,formula_text,sort_order,display_level,is_bold)
SELECT id,'TOTAL_ASSET','جمع دارایی‌ها','FORMULA','AUTO','CURRENT_ASSET+NONCURRENT_ASSET',30,1,1 FROM financial_statement_templates WHERE code='STD_BS';
INSERT IGNORE INTO financial_statement_lines(template_id,line_code,title_fa,line_type,normal_sign,formula_text,sort_order,display_level,is_bold)
SELECT id,'CURRENT_LIABILITY','بدهی‌های جاری','ACCOUNT_SUM','CREDIT',NULL,40,1,0 FROM financial_statement_templates WHERE code='STD_BS';
INSERT IGNORE INTO financial_statement_lines(template_id,line_code,title_fa,line_type,normal_sign,formula_text,sort_order,display_level,is_bold)
SELECT id,'NONCURRENT_LIABILITY','بدهی‌های غیرجاری','ACCOUNT_SUM','CREDIT',NULL,50,1,0 FROM financial_statement_templates WHERE code='STD_BS';
INSERT IGNORE INTO financial_statement_lines(template_id,line_code,title_fa,line_type,normal_sign,formula_text,sort_order,display_level,is_bold)
SELECT id,'TOTAL_LIABILITY','جمع بدهی‌ها','FORMULA','AUTO','CURRENT_LIABILITY+NONCURRENT_LIABILITY',60,1,1 FROM financial_statement_templates WHERE code='STD_BS';
INSERT IGNORE INTO financial_statement_lines(template_id,line_code,title_fa,line_type,normal_sign,formula_text,sort_order,display_level,is_bold)
SELECT id,'EQUITY','حقوق مالکانه','ACCOUNT_SUM','CREDIT',NULL,70,1,0 FROM financial_statement_templates WHERE code='STD_BS';
INSERT IGNORE INTO financial_statement_lines(template_id,line_code,title_fa,line_type,normal_sign,formula_text,sort_order,display_level,is_bold)
SELECT id,'CURRENT_EARNINGS','سود (زیان) جاری تا تاریخ گزارش','FORMULA','AUTO','0',80,1,0 FROM financial_statement_templates WHERE code='STD_BS';
INSERT IGNORE INTO financial_statement_lines(template_id,line_code,title_fa,line_type,normal_sign,formula_text,sort_order,display_level,is_bold)
SELECT id,'TOTAL_EQUITY','جمع حقوق مالکانه','FORMULA','AUTO','EQUITY+CURRENT_EARNINGS',90,1,1 FROM financial_statement_templates WHERE code='STD_BS';
INSERT IGNORE INTO financial_statement_lines(template_id,line_code,title_fa,line_type,normal_sign,formula_text,sort_order,display_level,is_bold)
SELECT id,'TOTAL_LIABILITY_EQUITY','جمع بدهی‌ها و حقوق مالکانه','FORMULA','AUTO','TOTAL_LIABILITY+TOTAL_EQUITY',100,1,1 FROM financial_statement_templates WHERE code='STD_BS';
INSERT IGNORE INTO financial_statement_lines(template_id,line_code,title_fa,line_type,normal_sign,formula_text,sort_order,display_level,is_bold)
SELECT id,'BALANCE_DIFFERENCE','اختلاف تراز','FORMULA','AUTO','TOTAL_ASSET-TOTAL_LIABILITY_EQUITY',110,1,1 FROM financial_statement_templates WHERE code='STD_BS';

INSERT IGNORE INTO financial_statement_account_maps(statement_line_id,company_id,account_id,sign_multiplier)
SELECT l.id,a.company_id,a.id,1
FROM financial_statement_lines l
JOIN financial_statement_templates t ON t.id=l.template_id
JOIN accounts a ON a.company_id=t.company_id AND a.statement_section=l.line_code
WHERE t.code IN ('STD_PL','STD_BS') AND l.line_type='ACCOUNT_SUM' AND l.line_code<>'EQUITY';

INSERT IGNORE INTO financial_statement_account_maps(statement_line_id,company_id,account_id,sign_multiplier)
SELECT l.id,a.company_id,a.id,1
FROM financial_statement_lines l
JOIN financial_statement_templates t ON t.id=l.template_id
JOIN accounts a ON a.company_id=t.company_id AND a.statement_section='EQUITY'
WHERE t.code='STD_BS' AND l.line_code='EQUITY';
