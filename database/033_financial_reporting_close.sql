CREATE TABLE IF NOT EXISTS fiscal_years (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  year_no INT NOT NULL,
  title VARCHAR(120) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  status ENUM('OPEN','SOFT_CLOSED','HARD_CLOSED') NOT NULL DEFAULT 'OPEN',
  closed_by BIGINT UNSIGNED NULL,
  closed_at DATETIME NULL,
  UNIQUE KEY uq_fy_company_year(company_id,year_no),
  CONSTRAINT fk_fy_reporting_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_fy_reporting_closer FOREIGN KEY(closed_by) REFERENCES users(id),
  CHECK(end_date>=start_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS fiscal_periods (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  fiscal_year_id BIGINT UNSIGNED NOT NULL,
  company_id BIGINT UNSIGNED NOT NULL,
  period_no TINYINT UNSIGNED NOT NULL,
  title VARCHAR(120) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  status ENUM('OPEN','SOFT_CLOSED','HARD_CLOSED') NOT NULL DEFAULT 'OPEN',
  closed_by BIGINT UNSIGNED NULL,
  closed_at DATETIME NULL,
  UNIQUE KEY uq_fp_year_period(fiscal_year_id,period_no),
  KEY ix_fp_company_date(company_id,start_date,end_date,status),
  CONSTRAINT fk_fp_year FOREIGN KEY(fiscal_year_id) REFERENCES fiscal_years(id) ON DELETE CASCADE,
  CONSTRAINT fk_fp_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_fp_closer FOREIGN KEY(closed_by) REFERENCES users(id),
  CHECK(period_no BETWEEN 1 AND 16),
  CHECK(end_date>=start_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS close_checklist_templates (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NULL,
  code VARCHAR(80) NOT NULL,
  title_fa VARCHAR(250) NOT NULL,
  check_type ENUM('SYSTEM','MANUAL') NOT NULL DEFAULT 'SYSTEM',
  severity ENUM('INFO','WARNING','BLOCKER') NOT NULL DEFAULT 'BLOCKER',
  check_code VARCHAR(100) NULL,
  description TEXT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_close_template(company_id,code),
  CONSTRAINT fk_cct_company FOREIGN KEY(company_id) REFERENCES companies(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS period_close_runs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  fiscal_period_id BIGINT UNSIGNED NOT NULL,
  run_no VARCHAR(80) NOT NULL,
  close_mode ENUM('SOFT','HARD') NOT NULL,
  status ENUM('DRAFT','CHECKED','BLOCKED','APPROVED','CLOSED','REOPENED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  blocker_count INT NOT NULL DEFAULT 0,
  warning_count INT NOT NULL DEFAULT 0,
  prepared_by BIGINT UNSIGNED NOT NULL,
  reviewed_by BIGINT UNSIGNED NULL,
  approved_by BIGINT UNSIGNED NULL,
  prepared_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reviewed_at DATETIME NULL,
  approved_at DATETIME NULL,
  closed_at DATETIME NULL,
  reopen_reason VARCHAR(1000) NULL,
  UNIQUE KEY uq_close_run(company_id,run_no),
  KEY ix_close_period(fiscal_period_id,status),
  CONSTRAINT fk_pcr_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_pcr_period FOREIGN KEY(fiscal_period_id) REFERENCES fiscal_periods(id),
  CONSTRAINT fk_pcr_preparer FOREIGN KEY(prepared_by) REFERENCES users(id),
  CONSTRAINT fk_pcr_reviewer FOREIGN KEY(reviewed_by) REFERENCES users(id),
  CONSTRAINT fk_pcr_approver FOREIGN KEY(approved_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS period_close_results (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  close_run_id BIGINT UNSIGNED NOT NULL,
  checklist_code VARCHAR(80) NOT NULL,
  title_fa VARCHAR(250) NOT NULL,
  severity ENUM('INFO','WARNING','BLOCKER') NOT NULL,
  status ENUM('PASS','FAIL','WAIVED','MANUAL_PENDING','MANUAL_DONE') NOT NULL,
  item_count INT NOT NULL DEFAULT 0,
  amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  details_json JSON NULL,
  evidence_ref VARCHAR(1000) NULL,
  note TEXT NULL,
  resolved_by BIGINT UNSIGNED NULL,
  resolved_at DATETIME NULL,
  UNIQUE KEY uq_close_result(close_run_id,checklist_code),
  CONSTRAINT fk_pcres_run FOREIGN KEY(close_run_id) REFERENCES period_close_runs(id) ON DELETE CASCADE,
  CONSTRAINT fk_pcres_user FOREIGN KEY(resolved_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

ALTER TABLE accounts
  ADD COLUMN statement_section ENUM('CURRENT_ASSET','NONCURRENT_ASSET','CURRENT_LIABILITY','NONCURRENT_LIABILITY','EQUITY','OPERATING_REVENUE','COST_OF_SALES','OPERATING_EXPENSE','OTHER_REVENUE','OTHER_EXPENSE','TAX','UNASSIGNED') NOT NULL DEFAULT 'UNASSIGNED',
  ADD COLUMN cash_flow_activity ENUM('OPERATING','INVESTING','FINANCING','CASH','UNASSIGNED') NOT NULL DEFAULT 'UNASSIGNED';

CREATE TABLE IF NOT EXISTS financial_statement_templates (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NULL,
  code VARCHAR(80) NOT NULL,
  title_fa VARCHAR(220) NOT NULL,
  statement_type ENUM('BALANCE_SHEET','PROFIT_LOSS','CASH_FLOW','EQUITY_CHANGES','CUSTOM') NOT NULL,
  is_system TINYINT(1) NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_fs_template(company_id,code),
  CONSTRAINT fk_fst_company FOREIGN KEY(company_id) REFERENCES companies(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS financial_statement_lines (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  template_id BIGINT UNSIGNED NOT NULL,
  parent_id BIGINT UNSIGNED NULL,
  line_code VARCHAR(80) NOT NULL,
  title_fa VARCHAR(250) NOT NULL,
  line_type ENUM('HEADER','ACCOUNT_SUM','FORMULA','SUBTOTAL','TOTAL') NOT NULL DEFAULT 'ACCOUNT_SUM',
  normal_sign ENUM('DEBIT','CREDIT','AUTO') NOT NULL DEFAULT 'AUTO',
  formula_text VARCHAR(1000) NULL,
  sort_order INT NOT NULL DEFAULT 0,
  display_level TINYINT NOT NULL DEFAULT 1,
  is_bold TINYINT(1) NOT NULL DEFAULT 0,
  UNIQUE KEY uq_fsl_template_code(template_id,line_code),
  CONSTRAINT fk_fsl_template FOREIGN KEY(template_id) REFERENCES financial_statement_templates(id) ON DELETE CASCADE,
  CONSTRAINT fk_fsl_parent FOREIGN KEY(parent_id) REFERENCES financial_statement_lines(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS financial_statement_account_maps (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  statement_line_id BIGINT UNSIGNED NOT NULL,
  company_id BIGINT UNSIGNED NOT NULL,
  account_id BIGINT UNSIGNED NOT NULL,
  sign_multiplier DECIMAL(8,4) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_fsam_line_account(statement_line_id,company_id,account_id),
  CONSTRAINT fk_fsam_line FOREIGN KEY(statement_line_id) REFERENCES financial_statement_lines(id) ON DELETE CASCADE,
  CONSTRAINT fk_fsam_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_fsam_account FOREIGN KEY(account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS cash_flow_mappings (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  source_type VARCHAR(100) NULL,
  counter_account_id BIGINT UNSIGNED NULL,
  activity ENUM('OPERATING','INVESTING','FINANCING') NOT NULL,
  title_fa VARCHAR(250) NOT NULL,
  priority INT NOT NULL DEFAULT 100,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  KEY ix_cfm_company(company_id,source_type,counter_account_id,priority),
  CONSTRAINT fk_cfm_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_cfm_account FOREIGN KEY(counter_account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS financial_report_snapshots (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  report_type VARCHAR(80) NOT NULL,
  as_of_date DATE NOT NULL,
  period_start DATE NULL,
  parameters_json JSON NULL,
  result_json JSON NOT NULL,
  source_hash VARCHAR(64) NOT NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_frs_reporting_company(company_id,report_type,as_of_date),
  CONSTRAINT fk_frs_reporting_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_frs_reporting_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT IGNORE INTO close_checklist_templates(company_id,code,title_fa,check_type,severity,check_code,sort_order)
SELECT id,'UNPOSTED_JOURNALS','اسناد حسابداری ثبت‌نشده','SYSTEM','BLOCKER','UNPOSTED_JOURNALS',10 FROM companies;
INSERT IGNORE INTO close_checklist_templates(company_id,code,title_fa,check_type,severity,check_code,sort_order)
SELECT id,'UNRECONCILED_BANK','گردش‌های بانکی تطبیق‌نشده','SYSTEM','BLOCKER','UNRECONCILED_BANK',20 FROM companies;
INSERT IGNORE INTO close_checklist_templates(company_id,code,title_fa,check_type,severity,check_code,sort_order)
SELECT id,'NEGATIVE_STOCK','موجودی منفی انبار','SYSTEM','BLOCKER','NEGATIVE_STOCK',30 FROM companies;
INSERT IGNORE INTO close_checklist_templates(company_id,code,title_fa,check_type,severity,check_code,sort_order)
SELECT id,'GRNI_OPEN','کالای دریافت‌شده صورتحساب‌نشده','SYSTEM','WARNING','GRNI_OPEN',40 FROM companies;
INSERT IGNORE INTO close_checklist_templates(company_id,code,title_fa,check_type,severity,check_code,sort_order)
SELECT id,'SUSPENSE_BALANCE','مانده حساب‌های انتظامی/واسط','SYSTEM','WARNING','SUSPENSE_BALANCE',50 FROM companies;
INSERT IGNORE INTO close_checklist_templates(company_id,code,title_fa,check_type,severity,check_code,sort_order)
SELECT id,'PAYROLL_STATUS','حقوق دوره تعیین تکلیف نشده','SYSTEM','WARNING','PAYROLL_STATUS',60 FROM companies;
INSERT IGNORE INTO close_checklist_templates(company_id,code,title_fa,check_type,severity,check_code,sort_order)
SELECT id,'FIXED_ASSET_DEPRECIATION','استهلاک دارایی ثابت دوره','SYSTEM','WARNING','FIXED_ASSET_DEPRECIATION',70 FROM companies;
INSERT IGNORE INTO close_checklist_templates(company_id,code,title_fa,check_type,severity,check_code,sort_order)
SELECT id,'MANAGEMENT_REVIEW','تأیید مدیر مالی بر گزارش‌های نهایی','MANUAL','BLOCKER',NULL,90 FROM companies;

UPDATE accounts SET statement_section='CURRENT_ASSET',cash_flow_activity='CASH' WHERE code IN ('110200','110210','110220');
UPDATE accounts SET statement_section='CURRENT_ASSET' WHERE code IN ('110100','120500','120900','130100');
UPDATE accounts SET statement_section='CURRENT_LIABILITY' WHERE code IN ('210500','210700','220100','220900');
UPDATE accounts SET statement_section='OPERATING_REVENUE' WHERE code='410100';
UPDATE accounts SET statement_section='OTHER_REVENUE' WHERE code='420100';
UPDATE accounts SET statement_section='COST_OF_SALES' WHERE code='510100';
UPDATE accounts SET statement_section='OPERATING_EXPENSE' WHERE account_type='EXPENSE' AND statement_section='UNASSIGNED';

DELIMITER $$
CREATE TRIGGER trg_journal_hard_close_insert
BEFORE INSERT ON journal_entries
FOR EACH ROW
BEGIN
  IF NEW.status IN ('POSTED','LOCKED') AND EXISTS(
    SELECT 1 FROM fiscal_periods fp
    WHERE fp.company_id=NEW.company_id AND fp.status='HARD_CLOSED'
      AND COALESCE(NEW.posting_date,NEW.entry_date) BETWEEN fp.start_date AND fp.end_date
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ACCOUNTING_PERIOD_HARD_CLOSED';
  END IF;
END$$

CREATE TRIGGER trg_journal_hard_close_update
BEFORE UPDATE ON journal_entries
FOR EACH ROW
BEGIN
  IF NEW.status IN ('POSTED','LOCKED') AND EXISTS(
    SELECT 1 FROM fiscal_periods fp
    WHERE fp.company_id=NEW.company_id AND fp.status='HARD_CLOSED'
      AND COALESCE(NEW.posting_date,NEW.entry_date) BETWEEN fp.start_date AND fp.end_date
  ) AND NOT (OLD.status IN ('POSTED','LOCKED') AND OLD.status=NEW.status AND COALESCE(OLD.posting_date,OLD.entry_date)=COALESCE(NEW.posting_date,NEW.entry_date)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ACCOUNTING_PERIOD_HARD_CLOSED';
  END IF;
END$$
DELIMITER ;
