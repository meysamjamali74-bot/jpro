-- TARAZPAD Enterprise 1.5 operational controls

ALTER TABLE accounts
  ADD COLUMN currency_revaluation_mode ENUM('NONE','MONETARY') NOT NULL DEFAULT 'NONE';

ALTER TABLE journal_lines
  ADD COLUMN currency_code CHAR(3) NULL,
  ADD COLUMN foreign_debit DECIMAL(28,6) NOT NULL DEFAULT 0,
  ADD COLUMN foreign_credit DECIMAL(28,6) NOT NULL DEFAULT 0,
  ADD COLUMN exchange_rate DECIMAL(28,10) NULL,
  ADD CONSTRAINT fk_jl_currency FOREIGN KEY(currency_code) REFERENCES currencies(code);

ALTER TABLE sales_invoices
  ADD COLUMN currency_code CHAR(3) NOT NULL DEFAULT 'IRR',
  ADD COLUMN exchange_rate DECIMAL(28,10) NOT NULL DEFAULT 1,
  ADD COLUMN foreign_net_total DECIMAL(28,6) NOT NULL DEFAULT 0,
  ADD CONSTRAINT fk_si_currency FOREIGN KEY(currency_code) REFERENCES currencies(code);

ALTER TABLE purchase_invoices
  ADD COLUMN currency_code CHAR(3) NOT NULL DEFAULT 'IRR',
  ADD COLUMN exchange_rate DECIMAL(28,10) NOT NULL DEFAULT 1,
  ADD COLUMN foreign_net_total DECIMAL(28,6) NOT NULL DEFAULT 0,
  ADD CONSTRAINT fk_pi_currency FOREIGN KEY(currency_code) REFERENCES currencies(code);

ALTER TABLE receipts
  ADD COLUMN currency_code CHAR(3) NOT NULL DEFAULT 'IRR',
  ADD COLUMN foreign_amount DECIMAL(28,6) NOT NULL DEFAULT 0,
  ADD COLUMN exchange_rate DECIMAL(28,10) NOT NULL DEFAULT 1,
  ADD CONSTRAINT fk_receipt_currency FOREIGN KEY(currency_code) REFERENCES currencies(code);

ALTER TABLE payments
  ADD COLUMN currency_code CHAR(3) NOT NULL DEFAULT 'IRR',
  ADD COLUMN foreign_amount DECIMAL(28,6) NOT NULL DEFAULT 0,
  ADD COLUMN exchange_rate DECIMAL(28,10) NOT NULL DEFAULT 1,
  ADD CONSTRAINT fk_payment_currency FOREIGN KEY(currency_code) REFERENCES currencies(code);

CREATE TABLE IF NOT EXISTS employee_user_links (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  employee_party_id BIGINT UNSIGNED NOT NULL,
  effective_from DATE NOT NULL,
  effective_to DATE NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_employee_user(company_id,user_id),
  UNIQUE KEY uq_employee_party_user(company_id,employee_party_id),
  CONSTRAINT fk_eul_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_eul_user FOREIGN KEY(user_id) REFERENCES users(id),
  CONSTRAINT fk_eul_party FOREIGN KEY(employee_party_id) REFERENCES parties(id),
  CONSTRAINT fk_eul_creator FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS commission_payroll_links (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  commission_result_id BIGINT UNSIGNED NOT NULL,
  employee_party_id BIGINT UNSIGNED NOT NULL,
  payroll_batch_id BIGINT UNSIGNED NOT NULL,
  payroll_slip_id BIGINT UNSIGNED NOT NULL,
  payroll_slip_line_id BIGINT UNSIGNED NOT NULL,
  amount DECIMAL(20,2) NOT NULL,
  status ENUM('TRANSFERRED','POSTED','PAID','REVERSED') NOT NULL DEFAULT 'TRANSFERRED',
  transferred_by BIGINT UNSIGNED NOT NULL,
  transferred_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  paid_at DATETIME NULL,
  UNIQUE KEY uq_commission_payroll_result(commission_result_id),
  KEY ix_cpl_batch(payroll_batch_id,status),
  CONSTRAINT fk_cpl_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_cpl_result FOREIGN KEY(commission_result_id) REFERENCES commission_results(id),
  CONSTRAINT fk_cpl_employee FOREIGN KEY(employee_party_id) REFERENCES parties(id),
  CONSTRAINT fk_cpl_batch FOREIGN KEY(payroll_batch_id) REFERENCES payroll_batches(id),
  CONSTRAINT fk_cpl_slip FOREIGN KEY(payroll_slip_id) REFERENCES payroll_slips(id),
  CONSTRAINT fk_cpl_line FOREIGN KEY(payroll_slip_line_id) REFERENCES payroll_slip_lines(id),
  CONSTRAINT fk_cpl_user FOREIGN KEY(transferred_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS maintenance_jobs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NULL,
  job_type ENUM('FULL_BACKUP','BINLOG_ARCHIVE','FILES_BACKUP','RESTORE_TEST','INTEGRITY_CHECK','CLEANUP') NOT NULL,
  status ENUM('QUEUED','RUNNING','SUCCESS','FAILED','CANCELLED') NOT NULL DEFAULT 'QUEUED',
  priority TINYINT NOT NULL DEFAULT 5,
  payload_json JSON NULL,
  result_json JSON NULL,
  requested_by BIGINT UNSIGNED NULL,
  requested_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  started_at DATETIME NULL,
  completed_at DATETIME NULL,
  error_text TEXT NULL,
  correlation_id VARCHAR(120) NULL,
  KEY ix_maintenance_queue(status,priority,requested_at),
  CONSTRAINT fk_mj_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_mj_user FOREIGN KEY(requested_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS system_maintenance_settings (
  id TINYINT UNSIGNED PRIMARY KEY,
  backup_directory VARCHAR(1000) NULL,
  full_backup_retention_days INT NOT NULL DEFAULT 30,
  monthly_backup_retention_months INT NOT NULL DEFAULT 24,
  require_restore_test_days INT NOT NULL DEFAULT 30,
  mysqldump_path VARCHAR(1000) NULL,
  files_root VARCHAR(1000) NULL,
  updated_by BIGINT UNSIGNED NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_sms_user FOREIGN KEY(updated_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT IGNORE INTO system_maintenance_settings(id) VALUES (1);

UPDATE accounts SET currency_revaluation_mode='MONETARY'
WHERE code IN ('110100','110200','120500','120900','210500','220100','220900');

INSERT IGNORE INTO dashboard_widget_catalog(code,title_fa,domain_code,widget_type,kpi_code,data_endpoint,default_size,min_role_code) VALUES
('FIN_CASH_POSITION','مانده نقد و بانک','FINANCE','KPI','CASH_POSITION','/api/iran/bi/kpi/CASH_POSITION','S','ACCOUNTANT'),
('FIN_AR','مانده حساب‌های دریافتنی','FINANCE','KPI','AR_BALANCE','/api/iran/bi/kpi/AR_BALANCE','S','ACCOUNTANT'),
('FIN_AP','مانده حساب‌های پرداختنی','FINANCE','KPI','AP_BALANCE','/api/iran/bi/kpi/AP_BALANCE','S','ACCOUNTANT'),
('FIN_OVERDUE_AR','مطالبات سررسید گذشته','FINANCE','KPI','OVERDUE_AR','/api/iran/bi/kpi/OVERDUE_AR','S','ACCOUNTANT'),
('FIN_PNL_MTD','سود ناخالص دوره','FINANCE','KPI','GROSS_PROFIT','/api/iran/bi/kpi/GROSS_PROFIT','S','FINANCE_MANAGER'),
('SALES_NET','فروش خالص','SALES','KPI','NET_SALES','/api/iran/bi/kpi/NET_SALES','S','SALES_MANAGER'),
('SALES_MARGIN','حاشیه سود ناخالص','SALES','KPI','GROSS_MARGIN','/api/iran/bi/kpi/GROSS_MARGIN','S','SALES_MANAGER'),
('SALES_TOP_CUSTOMERS','مشتریان برتر','SALES','TABLE',NULL,'/api/iran/bi/top-customers','L','SALES_MANAGER'),
('SALES_TOP_PRODUCTS','کالاهای پرفروش','SALES','TABLE',NULL,'/api/iran/bi/top-products','L','SALES_MANAGER'),
('INV_VALUE','ارزش موجودی','INVENTORY','KPI','INVENTORY_VALUE','/api/iran/bi/kpi/INVENTORY_VALUE','S','WAREHOUSE_MANAGER'),
('INV_LOW_STOCK','کالاهای زیر نقطه سفارش','INVENTORY','STATUS',NULL,'/api/iran/bi/low-stock','M','WAREHOUSE_MANAGER'),
('INV_NEAR_EXPIRY','کالاهای نزدیک انقضا','INVENTORY','TABLE',NULL,'/api/iran/bi/near-expiry','M','WAREHOUSE_MANAGER'),
('TREASURY_7D','سررسید ۷ روز آینده','TREASURY','TABLE',NULL,'/api/iran/bi/treasury-7d','M','FINANCE_MANAGER'),
('CRM_PIPELINE','قیف فرصت‌های فروش','CRM','FUNNEL',NULL,'/api/iran/bi/crm-pipeline','M','SALES_MANAGER'),
('CRM_OVERDUE_TASKS','پیگیری‌های معوق','CRM','STATUS',NULL,'/api/iran/bi/crm-overdue','M','SALES_MANAGER'),
('LOG_TRIPS','وضعیت سفرهای پخش','LOGISTICS','STATUS',NULL,'/api/iran/bi/trips','M','LOGISTICS_MANAGER'),
('LOG_DELIVERY_RATE','نرخ تحویل موفق','LOGISTICS','KPI','DELIVERY_RATE','/api/iran/bi/kpi/DELIVERY_RATE','S','LOGISTICS_MANAGER'),
('HR_HEADCOUNT','تعداد پرسنل فعال','HR','KPI','HEADCOUNT','/api/iran/bi/kpi/HEADCOUNT','S','HR_MANAGER'),
('HR_PAYROLL','حقوق خالص دوره','HR','KPI','PAYROLL_NET','/api/iran/bi/kpi/PAYROLL_NET','S','HR_MANAGER'),
('CTRL_EXCEPTIONS','استثناهای کنترلی باز','CONTROL','STATUS',NULL,'/api/iran/bi/control-exceptions','M','FINANCE_MANAGER'),
('SYS_BACKUP','وضعیت پشتیبان‌گیری','SYSTEM','STATUS',NULL,'/api/iran/system/backup-center','M','SUPER_ADMIN');
