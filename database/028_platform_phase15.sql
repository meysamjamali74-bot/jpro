-- TARAZPAD Enterprise 1.5 — platform hardening and analytics

CREATE TABLE IF NOT EXISTS company_accounting_policies (
  company_id BIGINT UNSIGNED PRIMARY KEY,
  inventory_valuation ENUM('FIFO','MOVING_AVERAGE','PERIODIC_WEIGHTED_AVERAGE') NOT NULL DEFAULT 'FIFO',
  revenue_recognition ENUM('INVOICE','WAREHOUSE_ISSUE','DELIVERY') NOT NULL DEFAULT 'INVOICE',
  inventory_issue_policy ENUM('AUTO_ON_INVOICE','FULFILLMENT','DISTRIBUTION') NOT NULL DEFAULT 'FULFILLMENT',
  allow_negative_inventory TINYINT(1) NOT NULL DEFAULT 0,
  fiscal_calendar ENUM('JALALI','GREGORIAN') NOT NULL DEFAULT 'JALALI',
  base_currency_code CHAR(3) NOT NULL DEFAULT 'IRR',
  reporting_currency_code CHAR(3) NOT NULL DEFAULT 'IRR',
  updated_by BIGINT UNSIGNED NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_cap_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_cap_user FOREIGN KEY(updated_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

ALTER TABLE sales_invoices
  ADD COLUMN warehouse_id BIGINT UNSIGNED NULL,
  ADD COLUMN fulfillment_status ENUM('NOT_REQUIRED','PENDING','RESERVED','PICKED','PACKED','ISSUED','DELIVERED','RETURNED') NOT NULL DEFAULT 'PENDING',
  ADD COLUMN inventory_issue_posted TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN inventory_issue_at DATETIME NULL,
  ADD COLUMN recognition_date DATE NULL,
  ADD CONSTRAINT fk_si_warehouse FOREIGN KEY(warehouse_id) REFERENCES warehouses(id);

CREATE TABLE IF NOT EXISTS sales_fulfillments (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  fulfillment_no VARCHAR(80) NOT NULL,
  sales_invoice_id BIGINT UNSIGNED NOT NULL,
  warehouse_id BIGINT UNSIGNED NOT NULL,
  fulfillment_type ENUM('DIRECT','DISTRIBUTION','TRANSFER_TO_ROUTE') NOT NULL DEFAULT 'DIRECT',
  status ENUM('DRAFT','RESERVED','PICKING','PICKED','PACKED','ISSUED','IN_TRANSIT','DELIVERED','PARTIAL','RETURNED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  reserved_at DATETIME NULL,
  picked_at DATETIME NULL,
  packed_at DATETIME NULL,
  issued_at DATETIME NULL,
  delivered_at DATETIME NULL,
  distribution_trip_id BIGINT UNSIGNED NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_fulfillment(company_id,fulfillment_no),
  KEY ix_fulfillment_invoice(sales_invoice_id,status),
  CONSTRAINT fk_sf_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_sf_invoice FOREIGN KEY(sales_invoice_id) REFERENCES sales_invoices(id),
  CONSTRAINT fk_sf_warehouse FOREIGN KEY(warehouse_id) REFERENCES warehouses(id),
  CONSTRAINT fk_sf_trip FOREIGN KEY(distribution_trip_id) REFERENCES trips(id),
  CONSTRAINT fk_sf_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sales_fulfillment_lines (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  fulfillment_id BIGINT UNSIGNED NOT NULL,
  sales_invoice_line_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  requested_qty DECIMAL(20,4) NOT NULL,
  reserved_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  picked_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  issued_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  delivered_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  returned_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  actual_unit_cost DECIMAL(20,6) NOT NULL DEFAULT 0,
  actual_cost_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  UNIQUE KEY uq_fulfillment_invoice_line(fulfillment_id,sales_invoice_line_id),
  CONSTRAINT fk_sfl_header FOREIGN KEY(fulfillment_id) REFERENCES sales_fulfillments(id) ON DELETE CASCADE,
  CONSTRAINT fk_sfl_invoice_line FOREIGN KEY(sales_invoice_line_id) REFERENCES sales_invoice_lines(id),
  CONSTRAINT fk_sfl_product FOREIGN KEY(product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS currencies (
  code CHAR(3) PRIMARY KEY,
  title_fa VARCHAR(100) NOT NULL,
  decimal_places TINYINT NOT NULL DEFAULT 2,
  is_active TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT IGNORE INTO currencies(code,title_fa,decimal_places) VALUES
('IRR','ریال ایران',0),('USD','دلار آمریکا',2),('EUR','یورو',2),('AED','درهم امارات',2),('TRY','لیر ترکیه',2),('GBP','پوند بریتانیا',2);

CREATE TABLE IF NOT EXISTS exchange_rates (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  rate_date DATE NOT NULL,
  from_currency CHAR(3) NOT NULL,
  to_currency CHAR(3) NOT NULL,
  rate_type ENUM('OFFICIAL','FREE','CUSTOM','CLOSING','AVERAGE') NOT NULL DEFAULT 'CUSTOM',
  rate DECIMAL(28,10) NOT NULL,
  source VARCHAR(200) NULL,
  entered_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_fx_rate(company_id,rate_date,from_currency,to_currency,rate_type),
  CONSTRAINT fk_fx_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_fx_from FOREIGN KEY(from_currency) REFERENCES currencies(code),
  CONSTRAINT fk_fx_to FOREIGN KEY(to_currency) REFERENCES currencies(code),
  CONSTRAINT fk_fx_user FOREIGN KEY(entered_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS fx_revaluation_runs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  run_no VARCHAR(80) NOT NULL,
  revaluation_date DATE NOT NULL,
  rate_type ENUM('OFFICIAL','FREE','CUSTOM','CLOSING','AVERAGE') NOT NULL DEFAULT 'CLOSING',
  status ENUM('DRAFT','CALCULATED','REVIEWED','POSTED','VOID') NOT NULL DEFAULT 'DRAFT',
  gain_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  loss_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  journal_entry_id BIGINT UNSIGNED NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  reviewed_by BIGINT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_fx_run(company_id,run_no),
  CONSTRAINT fk_fxr_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_fxr_journal FOREIGN KEY(journal_entry_id) REFERENCES journal_entries(id),
  CONSTRAINT fk_fxr_creator FOREIGN KEY(created_by) REFERENCES users(id),
  CONSTRAINT fk_fxr_reviewer FOREIGN KEY(reviewed_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS fx_revaluation_lines (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  run_id BIGINT UNSIGNED NOT NULL,
  account_id BIGINT UNSIGNED NOT NULL,
  party_id BIGINT UNSIGNED NULL,
  currency_code CHAR(3) NOT NULL,
  foreign_balance DECIMAL(28,6) NOT NULL,
  old_base_balance DECIMAL(20,2) NOT NULL,
  closing_rate DECIMAL(28,10) NOT NULL,
  new_base_balance DECIMAL(20,2) NOT NULL,
  gain_loss_amount DECIMAL(20,2) NOT NULL,
  CONSTRAINT fk_fxrl_run FOREIGN KEY(run_id) REFERENCES fx_revaluation_runs(id) ON DELETE CASCADE,
  CONSTRAINT fk_fxrl_account FOREIGN KEY(account_id) REFERENCES accounts(id),
  CONSTRAINT fk_fxrl_party FOREIGN KEY(party_id) REFERENCES parties(id),
  CONSTRAINT fk_fxrl_currency FOREIGN KEY(currency_code) REFERENCES currencies(code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS intercompany_relationships (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  counterparty_company_id BIGINT UNSIGNED NOT NULL,
  due_from_account_id BIGINT UNSIGNED NOT NULL,
  due_to_account_id BIGINT UNSIGNED NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_intercompany_pair(company_id,counterparty_company_id),
  CONSTRAINT fk_icr_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_icr_counter FOREIGN KEY(counterparty_company_id) REFERENCES companies(id),
  CONSTRAINT fk_icr_from FOREIGN KEY(due_from_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_icr_to FOREIGN KEY(due_to_account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS intercompany_transactions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  source_company_id BIGINT UNSIGNED NOT NULL,
  target_company_id BIGINT UNSIGNED NOT NULL,
  transaction_date DATE NOT NULL,
  source_type VARCHAR(80) NOT NULL,
  source_id BIGINT UNSIGNED NOT NULL,
  amount DECIMAL(20,2) NOT NULL,
  currency_code CHAR(3) NOT NULL DEFAULT 'IRR',
  source_journal_entry_id BIGINT UNSIGNED NULL,
  target_journal_entry_id BIGINT UNSIGNED NULL,
  status ENUM('DRAFT','POSTED_SOURCE','POSTED_BOTH','RECONCILED','ELIMINATED','VOID') NOT NULL DEFAULT 'DRAFT',
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_intercompany_source(source_company_id,target_company_id,source_type,source_id),
  CONSTRAINT fk_ict_source_company FOREIGN KEY(source_company_id) REFERENCES companies(id),
  CONSTRAINT fk_ict_target_company FOREIGN KEY(target_company_id) REFERENCES companies(id),
  CONSTRAINT fk_ict_currency FOREIGN KEY(currency_code) REFERENCES currencies(code),
  CONSTRAINT fk_ict_source_journal FOREIGN KEY(source_journal_entry_id) REFERENCES journal_entries(id),
  CONSTRAINT fk_ict_target_journal FOREIGN KEY(target_journal_entry_id) REFERENCES journal_entries(id),
  CONSTRAINT fk_ict_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS consolidation_runs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  run_no VARCHAR(80) NOT NULL,
  reporting_date DATE NOT NULL,
  reporting_currency CHAR(3) NOT NULL DEFAULT 'IRR',
  included_companies_json JSON NOT NULL,
  status ENUM('DRAFT','CALCULATED','REVIEWED','FINAL') NOT NULL DEFAULT 'DRAFT',
  total_assets DECIMAL(20,2) NOT NULL DEFAULT 0,
  total_liabilities DECIMAL(20,2) NOT NULL DEFAULT 0,
  total_revenue DECIMAL(20,2) NOT NULL DEFAULT 0,
  total_expense DECIMAL(20,2) NOT NULL DEFAULT 0,
  elimination_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_consolidation_run(run_no),
  CONSTRAINT fk_cons_currency FOREIGN KEY(reporting_currency) REFERENCES currencies(code),
  CONSTRAINT fk_cons_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS consolidation_lines (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  run_id BIGINT UNSIGNED NOT NULL,
  company_id BIGINT UNSIGNED NULL,
  account_code VARCHAR(80) NOT NULL,
  account_title VARCHAR(250) NOT NULL,
  account_type VARCHAR(60) NOT NULL,
  amount DECIMAL(20,2) NOT NULL,
  elimination_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  consolidated_amount DECIMAL(20,2) NOT NULL,
  details_json JSON NULL,
  KEY ix_consolidation_line(run_id,account_type,account_code),
  CONSTRAINT fk_consl_run FOREIGN KEY(run_id) REFERENCES consolidation_runs(id) ON DELETE CASCADE,
  CONSTRAINT fk_consl_company FOREIGN KEY(company_id) REFERENCES companies(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS semantic_models (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NULL,
  code VARCHAR(80) NOT NULL,
  title_fa VARCHAR(200) NOT NULL,
  domain_code VARCHAR(80) NOT NULL,
  base_source VARCHAR(250) NOT NULL,
  grain_description VARCHAR(500) NOT NULL,
  row_filter_sql TEXT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  version_no INT NOT NULL DEFAULT 1,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_semantic_model(company_id,code,version_no),
  CONSTRAINT fk_sm_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_sm_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS semantic_fields (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  semantic_model_id BIGINT UNSIGNED NOT NULL,
  code VARCHAR(100) NOT NULL,
  title_fa VARCHAR(200) NOT NULL,
  field_type ENUM('DIMENSION','MEASURE','DATE','ATTRIBUTE','KPI') NOT NULL,
  data_type ENUM('STRING','NUMBER','CURRENCY','PERCENT','DATE','DATETIME','BOOLEAN') NOT NULL,
  expression_sql TEXT NOT NULL,
  aggregation ENUM('NONE','SUM','COUNT','COUNT_DISTINCT','AVG','MIN','MAX') NOT NULL DEFAULT 'NONE',
  format_json JSON NULL,
  lineage_json JSON NULL,
  is_filterable TINYINT(1) NOT NULL DEFAULT 1,
  is_groupable TINYINT(1) NOT NULL DEFAULT 1,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_semantic_field(semantic_model_id,code),
  CONSTRAINT fk_sf_model FOREIGN KEY(semantic_model_id) REFERENCES semantic_models(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS kpi_definitions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NULL,
  code VARCHAR(100) NOT NULL,
  title_fa VARCHAR(200) NOT NULL,
  domain_code VARCHAR(80) NOT NULL,
  semantic_model_id BIGINT UNSIGNED NULL,
  formula_json JSON NOT NULL,
  target_json JSON NULL,
  thresholds_json JSON NULL,
  owner_role_code VARCHAR(80) NULL,
  version_no INT NOT NULL DEFAULT 1,
  effective_from DATE NOT NULL,
  effective_to DATE NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_kpi(company_id,code,version_no),
  CONSTRAINT fk_kpi_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_kpi_model FOREIGN KEY(semantic_model_id) REFERENCES semantic_models(id),
  CONSTRAINT fk_kpi_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS dashboard_widget_catalog (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(100) NOT NULL UNIQUE,
  title_fa VARCHAR(200) NOT NULL,
  domain_code VARCHAR(80) NOT NULL,
  widget_type ENUM('KPI','TABLE','LINE','BAR','AREA','DONUT','FUNNEL','GAUGE','HEATMAP','STATUS','MAP') NOT NULL,
  kpi_code VARCHAR(100) NULL,
  data_endpoint VARCHAR(300) NULL,
  default_size ENUM('S','M','L','XL') NOT NULL DEFAULT 'M',
  config_json JSON NULL,
  min_role_code VARCHAR(80) NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS user_dashboards (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  dashboard_code VARCHAR(80) NOT NULL DEFAULT 'PERSONAL',
  title VARCHAR(200) NOT NULL,
  scope ENUM('PERSONAL','TEAM','ROLE','COMPANY','EXECUTIVE') NOT NULL DEFAULT 'PERSONAL',
  global_filters_json JSON NULL,
  is_default TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_user_dashboard(company_id,user_id,dashboard_code),
  CONSTRAINT fk_ud_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_ud_user FOREIGN KEY(user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS user_dashboard_widgets (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  dashboard_id BIGINT UNSIGNED NOT NULL,
  widget_code VARCHAR(100) NOT NULL,
  position_x INT NOT NULL DEFAULT 0,
  position_y INT NOT NULL DEFAULT 0,
  width_units INT NOT NULL DEFAULT 4,
  height_units INT NOT NULL DEFAULT 2,
  config_json JSON NULL,
  is_visible TINYINT(1) NOT NULL DEFAULT 1,
  sort_order INT NOT NULL DEFAULT 0,
  UNIQUE KEY uq_dashboard_widget(dashboard_id,widget_code),
  CONSTRAINT fk_udw_dashboard FOREIGN KEY(dashboard_id) REFERENCES user_dashboards(id) ON DELETE CASCADE,
  CONSTRAINT fk_udw_catalog FOREIGN KEY(widget_code) REFERENCES dashboard_widget_catalog(code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS segregation_of_duties_rules (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NULL,
  code VARCHAR(100) NOT NULL,
  title_fa VARCHAR(250) NOT NULL,
  role_a VARCHAR(80) NOT NULL,
  role_b VARCHAR(80) NOT NULL,
  severity ENUM('WARNING','HIGH','CRITICAL') NOT NULL DEFAULT 'HIGH',
  action ENUM('WARN','BLOCK','REQUIRE_APPROVAL') NOT NULL DEFAULT 'BLOCK',
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_sod_rule(company_id,code),
  CONSTRAINT fk_sod_company FOREIGN KEY(company_id) REFERENCES companies(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS field_access_policies (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NULL,
  entity_type VARCHAR(100) NOT NULL,
  field_name VARCHAR(100) NOT NULL,
  role_code VARCHAR(80) NOT NULL,
  access_mode ENUM('HIDDEN','MASKED','READ_ONLY','FULL') NOT NULL DEFAULT 'MASKED',
  mask_pattern VARCHAR(120) NULL,
  UNIQUE KEY uq_field_policy(company_id,entity_type,field_name,role_code),
  CONSTRAINT fk_fap_company FOREIGN KEY(company_id) REFERENCES companies(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS export_policies (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NULL,
  role_code VARCHAR(80) NOT NULL,
  domain_code VARCHAR(80) NOT NULL,
  can_export TINYINT(1) NOT NULL DEFAULT 0,
  max_rows INT NOT NULL DEFAULT 10000,
  require_reason TINYINT(1) NOT NULL DEFAULT 1,
  require_approval TINYINT(1) NOT NULL DEFAULT 0,
  watermark_exports TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_export_policy(company_id,role_code,domain_code),
  CONSTRAINT fk_ep_company FOREIGN KEY(company_id) REFERENCES companies(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS export_audit_logs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  domain_code VARCHAR(80) NOT NULL,
  report_code VARCHAR(100) NULL,
  row_count INT NOT NULL DEFAULT 0,
  reason VARCHAR(500) NULL,
  filters_json JSON NULL,
  file_hash VARCHAR(64) NULL,
  exported_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_eal_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_eal_user FOREIGN KEY(user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS backup_runs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NULL,
  backup_type ENUM('FULL','INCREMENTAL','BINLOG','FILES','CONFIG') NOT NULL,
  started_at DATETIME NOT NULL,
  completed_at DATETIME NULL,
  status ENUM('RUNNING','SUCCESS','FAILED','VERIFICATION_FAILED') NOT NULL,
  storage_location VARCHAR(1000) NULL,
  size_bytes BIGINT UNSIGNED NULL,
  sha256 VARCHAR(64) NULL,
  error_text TEXT NULL,
  retention_until DATE NULL,
  created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
  KEY ix_backup_status(status,started_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS restore_tests (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  backup_run_id BIGINT UNSIGNED NOT NULL,
  tested_at DATETIME NOT NULL,
  status ENUM('SUCCESS','FAILED') NOT NULL,
  integrity_checks_json JSON NULL,
  duration_seconds INT NULL,
  error_text TEXT NULL,
  tested_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
  CONSTRAINT fk_rt_backup FOREIGN KEY(backup_run_id) REFERENCES backup_runs(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS system_health_snapshots (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  captured_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  service_name VARCHAR(100) NOT NULL,
  status ENUM('HEALTHY','DEGRADED','UNHEALTHY') NOT NULL,
  latency_ms DECIMAL(12,2) NULL,
  cpu_percent DECIMAL(8,4) NULL,
  memory_percent DECIMAL(8,4) NULL,
  db_connections INT NULL,
  queue_depth INT NULL,
  error_rate DECIMAL(10,6) NULL,
  details_json JSON NULL,
  KEY ix_health_time(service_name,captured_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS background_job_failures (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  job_name VARCHAR(150) NOT NULL,
  correlation_id VARCHAR(120) NULL,
  payload_json JSON NULL,
  error_text TEXT NOT NULL,
  retry_count INT NOT NULL DEFAULT 0,
  status ENUM('FAILED','RETRYING','RESOLVED','IGNORED') NOT NULL DEFAULT 'FAILED',
  first_failed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_failed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  resolved_at DATETIME NULL,
  KEY ix_job_failure(status,last_failed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'710100','زیان تسعیر ارز',3,'DEBIT','EXPENSE',1 FROM companies;
INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'420100','سود تسعیر ارز',3,'CREDIT','REVENUE',1 FROM companies;
INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'120900','حساب‌های دریافتنی بین‌شرکتی',3,'DEBIT','ASSET',1 FROM companies;
INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'220900','حساب‌های پرداختنی بین‌شرکتی',3,'CREDIT','LIABILITY',1 FROM companies;

INSERT IGNORE INTO company_accounting_policies(company_id,updated_by)
SELECT c.id,MIN(u.id) FROM companies c JOIN users u ON u.company_id=c.id GROUP BY c.id;
