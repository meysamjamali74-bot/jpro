INSERT IGNORE INTO roles(code,title,is_system) VALUES
('CRM_MANAGER','مدیر ارتباط با مشتری',1),
('CUSTOMER_SERVICE','کارشناس خدمات مشتریان',1),
('BPM_MANAGER','مدیر فرایندها و اتوماسیون',1),
('DMS_MANAGER','مدیر اسناد و مکاتبات',1);

ALTER TABLE loyalty_accounts
  ADD COLUMN lifetime_points DECIMAL(20,2) NOT NULL DEFAULT 0,
  ADD COLUMN lifetime_spend DECIMAL(20,2) NOT NULL DEFAULT 0,
  ADD COLUMN last_activity_at DATETIME NULL;

ALTER TABLE loyalty_ledger
  ADD COLUMN journal_entry_id BIGINT UNSIGNED NULL,
  ADD COLUMN approved_by BIGINT UNSIGNED NULL,
  ADD COLUMN approved_at DATETIME NULL,
  ADD CONSTRAINT fk_ll_journal FOREIGN KEY(journal_entry_id) REFERENCES journal_entries(id),
  ADD CONSTRAINT fk_ll_approved_by FOREIGN KEY(approved_by) REFERENCES users(id);

CREATE TABLE IF NOT EXISTS loyalty_accounting_settings (
  company_id BIGINT UNSIGNED PRIMARY KEY,
  loyalty_expense_account_id BIGINT UNSIGNED NOT NULL,
  loyalty_liability_account_id BIGINT UNSIGNED NOT NULL,
  wallet_liability_account_id BIGINT UNSIGNED NOT NULL,
  point_monetary_value DECIMAL(20,6) NOT NULL DEFAULT 0,
  updated_by BIGINT UNSIGNED NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_las_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_las_exp FOREIGN KEY(loyalty_expense_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_las_liab FOREIGN KEY(loyalty_liability_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_las_wallet FOREIGN KEY(wallet_liability_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_las_user FOREIGN KEY(updated_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'210710','کیف پول مشتریان',3,'CREDIT','LIABILITY',1 FROM companies;

INSERT IGNORE INTO loyalty_tiers(company_id,code,title,min_points,min_annual_spend,priority)
SELECT id,'NORMAL','عادی',0,0,10 FROM companies;
INSERT IGNORE INTO loyalty_tiers(company_id,code,title,min_points,min_annual_spend,priority)
SELECT id,'BRONZE','برنزی',1000,0,20 FROM companies;
INSERT IGNORE INTO loyalty_tiers(company_id,code,title,min_points,min_annual_spend,priority)
SELECT id,'SILVER','نقره‌ای',5000,0,30 FROM companies;
INSERT IGNORE INTO loyalty_tiers(company_id,code,title,min_points,min_annual_spend,priority)
SELECT id,'GOLD','طلایی',15000,0,40 FROM companies;
INSERT IGNORE INTO loyalty_tiers(company_id,code,title,min_points,min_annual_spend,priority)
SELECT id,'VIP','ویژه',50000,0,50 FROM companies;

INSERT IGNORE INTO loyalty_accounting_settings(company_id,loyalty_expense_account_id,loyalty_liability_account_id,wallet_liability_account_id,point_monetary_value,updated_by)
SELECT c.id,e.id,l.id,w.id,0,u.id
FROM companies c
JOIN accounts e ON e.company_id=c.id AND e.code='620100'
JOIN accounts l ON l.company_id=c.id AND l.code='210700'
JOIN accounts w ON w.company_id=c.id AND w.code='210710'
JOIN users u ON u.company_id=c.id
WHERE u.id=(SELECT MIN(u2.id) FROM users u2 WHERE u2.company_id=c.id);
