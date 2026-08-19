CREATE TABLE IF NOT EXISTS company_year_end_settings (
  company_id BIGINT UNSIGNED PRIMARY KEY,
  retained_earnings_account_id BIGINT UNSIGNED NULL,
  current_year_profit_account_id BIGINT UNSIGNED NULL,
  require_all_periods_hard_closed TINYINT(1) NOT NULL DEFAULT 1,
  auto_create_opening_entry TINYINT(1) NOT NULL DEFAULT 1,
  updated_by BIGINT UNSIGNED NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_cyes_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_cyes_retained FOREIGN KEY(retained_earnings_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_cyes_current_profit FOREIGN KEY(current_year_profit_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_cyes_user FOREIGN KEY(updated_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS year_end_close_runs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  fiscal_year_id BIGINT UNSIGNED NOT NULL,
  next_fiscal_year_id BIGINT UNSIGNED NULL,
  run_no VARCHAR(80) NOT NULL,
  status ENUM('DRAFT','CALCULATED','REVIEWED','APPROVED','POSTED','OPENING_POSTED','REVERSED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  revenue_balance DECIMAL(20,2) NOT NULL DEFAULT 0,
  expense_balance DECIMAL(20,2) NOT NULL DEFAULT 0,
  net_profit_loss DECIMAL(20,2) NOT NULL DEFAULT 0,
  balance_sheet_debit DECIMAL(20,2) NOT NULL DEFAULT 0,
  balance_sheet_credit DECIMAL(20,2) NOT NULL DEFAULT 0,
  closing_journal_entry_id BIGINT UNSIGNED NULL,
  opening_journal_entry_id BIGINT UNSIGNED NULL,
  source_hash VARCHAR(64) NULL,
  prepared_by BIGINT UNSIGNED NOT NULL,
  reviewed_by BIGINT UNSIGNED NULL,
  approved_by BIGINT UNSIGNED NULL,
  posted_by BIGINT UNSIGNED NULL,
  prepared_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  calculated_at DATETIME NULL,
  reviewed_at DATETIME NULL,
  approved_at DATETIME NULL,
  posted_at DATETIME NULL,
  note TEXT NULL,
  UNIQUE KEY uq_yec_company_year(company_id,fiscal_year_id),
  UNIQUE KEY uq_yec_run_no(company_id,run_no),
  CONSTRAINT fk_yec_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_yec_year FOREIGN KEY(fiscal_year_id) REFERENCES fiscal_years(id),
  CONSTRAINT fk_yec_next_year FOREIGN KEY(next_fiscal_year_id) REFERENCES fiscal_years(id),
  CONSTRAINT fk_yec_closing_je FOREIGN KEY(closing_journal_entry_id) REFERENCES journal_entries(id),
  CONSTRAINT fk_yec_opening_je FOREIGN KEY(opening_journal_entry_id) REFERENCES journal_entries(id),
  CONSTRAINT fk_yec_preparer FOREIGN KEY(prepared_by) REFERENCES users(id),
  CONSTRAINT fk_yec_reviewer FOREIGN KEY(reviewed_by) REFERENCES users(id),
  CONSTRAINT fk_yec_approver FOREIGN KEY(approved_by) REFERENCES users(id),
  CONSTRAINT fk_yec_poster FOREIGN KEY(posted_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS year_end_close_lines (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  run_id BIGINT UNSIGNED NOT NULL,
  account_id BIGINT UNSIGNED NOT NULL,
  account_code VARCHAR(64) NOT NULL,
  account_title VARCHAR(255) NOT NULL,
  account_type ENUM('ASSET','LIABILITY','EQUITY','REVENUE','EXPENSE') NOT NULL,
  ending_debit DECIMAL(20,2) NOT NULL DEFAULT 0,
  ending_credit DECIMAL(20,2) NOT NULL DEFAULT 0,
  closing_debit DECIMAL(20,2) NOT NULL DEFAULT 0,
  closing_credit DECIMAL(20,2) NOT NULL DEFAULT 0,
  opening_debit DECIMAL(20,2) NOT NULL DEFAULT 0,
  opening_credit DECIMAL(20,2) NOT NULL DEFAULT 0,
  UNIQUE KEY uq_yec_line(run_id,account_id),
  CONSTRAINT fk_yecl_run FOREIGN KEY(run_id) REFERENCES year_end_close_runs(id) ON DELETE CASCADE,
  CONSTRAINT fk_yecl_account FOREIGN KEY(account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS compliance_obligation_types (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(80) NOT NULL UNIQUE,
  title_fa VARCHAR(250) NOT NULL,
  authority_fa VARCHAR(250) NULL,
  category ENUM('VAT','TAXPAYER_SYSTEM','SALARY_TAX','SOCIAL_SECURITY','WITHHOLDING','CORPORATE_TAX','OTHER') NOT NULL,
  period_type ENUM('MONTHLY','QUARTERLY','ANNUAL','EVENT') NOT NULL,
  requires_filing TINYINT(1) NOT NULL DEFAULT 1,
  requires_payment TINYINT(1) NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS compliance_rule_versions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  obligation_type_id BIGINT UNSIGNED NOT NULL,
  company_id BIGINT UNSIGNED NULL,
  version_no INT NOT NULL,
  effective_from DATE NOT NULL,
  effective_to DATE NULL,
  due_rule_json JSON NOT NULL,
  calculation_rule_json JSON NULL,
  legal_reference VARCHAR(1000) NULL,
  note TEXT NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_compliance_rule(obligation_type_id,company_id,version_no),
  KEY ix_compliance_rule_effective(obligation_type_id,effective_from,effective_to),
  CONSTRAINT fk_crv_type FOREIGN KEY(obligation_type_id) REFERENCES compliance_obligation_types(id),
  CONSTRAINT fk_crv_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_crv_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS compliance_periods (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  obligation_type_id BIGINT UNSIGNED NOT NULL,
  rule_version_id BIGINT UNSIGNED NULL,
  period_key VARCHAR(80) NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  due_date DATE NULL,
  status ENUM('OPEN','CALCULATED','READY_TO_FILE','FILED','ACCEPTED','REJECTED','PAYMENT_DUE','PAID','CLOSED','NOT_APPLICABLE') NOT NULL DEFAULT 'OPEN',
  calculated_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  payable_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  filing_reference VARCHAR(250) NULL,
  filing_at DATETIME NULL,
  payment_reference VARCHAR(250) NULL,
  payment_at DATETIME NULL,
  source_hash VARCHAR(64) NULL,
  prepared_by BIGINT UNSIGNED NULL,
  reviewed_by BIGINT UNSIGNED NULL,
  approved_by BIGINT UNSIGNED NULL,
  note TEXT NULL,
  UNIQUE KEY uq_compliance_period(company_id,obligation_type_id,period_key),
  KEY ix_compliance_due(company_id,status,due_date),
  CONSTRAINT fk_cp_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_cp_type FOREIGN KEY(obligation_type_id) REFERENCES compliance_obligation_types(id),
  CONSTRAINT fk_cp_rule FOREIGN KEY(rule_version_id) REFERENCES compliance_rule_versions(id),
  CONSTRAINT fk_cp_preparer FOREIGN KEY(prepared_by) REFERENCES users(id),
  CONSTRAINT fk_cp_reviewer FOREIGN KEY(reviewed_by) REFERENCES users(id),
  CONSTRAINT fk_cp_approver FOREIGN KEY(approved_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS compliance_documents (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  compliance_period_id BIGINT UNSIGNED NOT NULL,
  document_type VARCHAR(80) NOT NULL,
  file_ref VARCHAR(1000) NULL,
  document_hash VARCHAR(64) NULL,
  metadata_json JSON NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_cd_period FOREIGN KEY(compliance_period_id) REFERENCES compliance_periods(id) ON DELETE CASCADE,
  CONSTRAINT fk_cd_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT IGNORE INTO compliance_obligation_types(code,title_fa,authority_fa,category,period_type,requires_filing,requires_payment) VALUES
('IR_VAT','اظهارنامه/تکالیف ارزش افزوده','سازمان امور مالیاتی کشور','VAT','QUARTERLY',1,1),
('IR_TAXPAYER_INVOICE','صورتحساب الکترونیکی و سامانه مؤدیان','سازمان امور مالیاتی کشور','TAXPAYER_SYSTEM','EVENT',1,0),
('IR_SALARY_TAX','مالیات حقوق','سازمان امور مالیاتی کشور','SALARY_TAX','MONTHLY',1,1),
('IR_SOCIAL_SECURITY','لیست و حق بیمه کارکنان','سازمان تأمین اجتماعی','SOCIAL_SECURITY','MONTHLY',1,1),
('IR_CORPORATE_TAX','اظهارنامه مالیات عملکرد اشخاص حقوقی','سازمان امور مالیاتی کشور','CORPORATE_TAX','ANNUAL',1,1);

-- No due dates, rates or legal deadlines are hard-coded here. They are versioned in compliance_rule_versions.
