-- TARAZPAD Enterprise 1.3 — management finance, AR/AP control, assets, costing and projects

CREATE TABLE IF NOT EXISTS ar_credit_notes (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  credit_note_no VARCHAR(80) NOT NULL,
  note_date DATE NOT NULL,
  customer_party_id BIGINT UNSIGNED NOT NULL,
  sales_invoice_id BIGINT UNSIGNED NULL,
  reason_code ENUM('RETURN','PRICE_ADJUSTMENT','DISCOUNT','CANCELLATION','OTHER') NOT NULL DEFAULT 'OTHER',
  status ENUM('DRAFT','APPROVED','POSTED','APPLIED','VOID') NOT NULL DEFAULT 'DRAFT',
  net_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  tax_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  total_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  journal_entry_id BIGINT UNSIGNED NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  approved_by BIGINT UNSIGNED NULL,
  approved_at DATETIME NULL,
  posted_at DATETIME NULL,
  notes VARCHAR(1000) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_ar_credit_note(company_id,credit_note_no),
  CONSTRAINT fk_arcn_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_arcn_customer FOREIGN KEY(customer_party_id) REFERENCES parties(id),
  CONSTRAINT fk_arcn_invoice FOREIGN KEY(sales_invoice_id) REFERENCES sales_invoices(id),
  CONSTRAINT fk_arcn_journal FOREIGN KEY(journal_entry_id) REFERENCES journal_entries(id),
  CONSTRAINT fk_arcn_creator FOREIGN KEY(created_by) REFERENCES users(id),
  CONSTRAINT fk_arcn_approver FOREIGN KEY(approved_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS ar_credit_note_lines (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  credit_note_id BIGINT UNSIGNED NOT NULL,
  sales_invoice_line_id BIGINT UNSIGNED NULL,
  product_id BIGINT UNSIGNED NULL,
  description VARCHAR(500) NULL,
  quantity DECIMAL(20,4) NOT NULL DEFAULT 0,
  unit_amount DECIMAL(20,4) NOT NULL DEFAULT 0,
  net_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  tax_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  total_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  inventory_return_required TINYINT(1) NOT NULL DEFAULT 0,
  inventory_return_posted TINYINT(1) NOT NULL DEFAULT 0,
  CONSTRAINT fk_arcnl_header FOREIGN KEY(credit_note_id) REFERENCES ar_credit_notes(id) ON DELETE CASCADE,
  CONSTRAINT fk_arcnl_invoice_line FOREIGN KEY(sales_invoice_line_id) REFERENCES sales_invoice_lines(id),
  CONSTRAINT fk_arcnl_product FOREIGN KEY(product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS ap_debit_notes (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  debit_note_no VARCHAR(80) NOT NULL,
  note_date DATE NOT NULL,
  supplier_party_id BIGINT UNSIGNED NOT NULL,
  purchase_invoice_id BIGINT UNSIGNED NULL,
  reason_code ENUM('PURCHASE_RETURN','PRICE_ADJUSTMENT','CLAIM','DISCOUNT','OTHER') NOT NULL DEFAULT 'OTHER',
  status ENUM('DRAFT','APPROVED','POSTED','APPLIED','VOID') NOT NULL DEFAULT 'DRAFT',
  net_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  tax_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  total_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  journal_entry_id BIGINT UNSIGNED NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  approved_by BIGINT UNSIGNED NULL,
  approved_at DATETIME NULL,
  posted_at DATETIME NULL,
  notes VARCHAR(1000) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_ap_debit_note(company_id,debit_note_no),
  CONSTRAINT fk_apdn_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_apdn_supplier FOREIGN KEY(supplier_party_id) REFERENCES parties(id),
  CONSTRAINT fk_apdn_invoice FOREIGN KEY(purchase_invoice_id) REFERENCES purchase_invoices(id),
  CONSTRAINT fk_apdn_journal FOREIGN KEY(journal_entry_id) REFERENCES journal_entries(id),
  CONSTRAINT fk_apdn_creator FOREIGN KEY(created_by) REFERENCES users(id),
  CONSTRAINT fk_apdn_approver FOREIGN KEY(approved_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS ap_debit_note_lines (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  debit_note_id BIGINT UNSIGNED NOT NULL,
  purchase_invoice_line_id BIGINT UNSIGNED NULL,
  product_id BIGINT UNSIGNED NULL,
  description VARCHAR(500) NULL,
  quantity DECIMAL(20,4) NOT NULL DEFAULT 0,
  unit_amount DECIMAL(20,4) NOT NULL DEFAULT 0,
  net_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  tax_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  total_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  inventory_return_required TINYINT(1) NOT NULL DEFAULT 0,
  inventory_return_posted TINYINT(1) NOT NULL DEFAULT 0,
  CONSTRAINT fk_apdnl_header FOREIGN KEY(debit_note_id) REFERENCES ap_debit_notes(id) ON DELETE CASCADE,
  CONSTRAINT fk_apdnl_invoice_line FOREIGN KEY(purchase_invoice_line_id) REFERENCES purchase_invoice_lines(id),
  CONSTRAINT fk_apdnl_product FOREIGN KEY(product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS budget_headers (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  budget_no VARCHAR(80) NOT NULL,
  title VARCHAR(250) NOT NULL,
  fiscal_year_label VARCHAR(20) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  version_no INT NOT NULL DEFAULT 1,
  status ENUM('DRAFT','SUBMITTED','APPROVED','ACTIVE','CLOSED','VOID') NOT NULL DEFAULT 'DRAFT',
  created_by BIGINT UNSIGNED NOT NULL,
  approved_by BIGINT UNSIGNED NULL,
  approved_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_budget_no(company_id,budget_no),
  CONSTRAINT fk_budget_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_budget_creator FOREIGN KEY(created_by) REFERENCES users(id),
  CONSTRAINT fk_budget_approver FOREIGN KEY(approved_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS budget_lines (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  budget_id BIGINT UNSIGNED NOT NULL,
  account_id BIGINT UNSIGNED NOT NULL,
  branch_id BIGINT UNSIGNED NULL,
  department_code VARCHAR(80) NULL,
  cost_center_code VARCHAR(80) NULL,
  project_code VARCHAR(80) NULL,
  period_no TINYINT NOT NULL,
  budget_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  warning_percent DECIMAL(10,4) NOT NULL DEFAULT 90,
  control_mode ENUM('NONE','WARN','APPROVAL','BLOCK') NOT NULL DEFAULT 'WARN',
  UNIQUE KEY uq_budget_dimension(budget_id,account_id,branch_id,department_code,cost_center_code,project_code,period_no),
  KEY ix_budget_account(account_id,period_no),
  CONSTRAINT fk_bl_budget FOREIGN KEY(budget_id) REFERENCES budget_headers(id) ON DELETE CASCADE,
  CONSTRAINT fk_bl_account FOREIGN KEY(account_id) REFERENCES accounts(id),
  CONSTRAINT fk_bl_branch FOREIGN KEY(branch_id) REFERENCES branches(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS budget_commitments (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  budget_line_id BIGINT UNSIGNED NOT NULL,
  source_type VARCHAR(80) NOT NULL,
  source_id BIGINT UNSIGNED NOT NULL,
  commitment_date DATE NOT NULL,
  amount DECIMAL(20,2) NOT NULL,
  status ENUM('RESERVED','CONSUMED','RELEASED','VOID') NOT NULL DEFAULT 'RESERVED',
  consumed_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_budget_source(budget_line_id,source_type,source_id),
  CONSTRAINT fk_bc_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_bc_line FOREIGN KEY(budget_line_id) REFERENCES budget_lines(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS fixed_asset_classes (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  code VARCHAR(50) NOT NULL,
  title VARCHAR(200) NOT NULL,
  useful_life_months INT NOT NULL,
  depreciation_method ENUM('STRAIGHT_LINE','DECLINING_BALANCE','NO_DEPRECIATION') NOT NULL DEFAULT 'STRAIGHT_LINE',
  depreciation_rate DECIMAL(12,6) NULL,
  asset_account_id BIGINT UNSIGNED NOT NULL,
  accumulated_depreciation_account_id BIGINT UNSIGNED NOT NULL,
  depreciation_expense_account_id BIGINT UNSIGNED NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_asset_class(company_id,code),
  CONSTRAINT fk_fac_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_fac_asset_ac FOREIGN KEY(asset_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_fac_accdep_ac FOREIGN KEY(accumulated_depreciation_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_fac_dep_exp_ac FOREIGN KEY(depreciation_expense_account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS fixed_assets (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  asset_class_id BIGINT UNSIGNED NOT NULL,
  asset_no VARCHAR(80) NOT NULL,
  asset_tag VARCHAR(100) NULL,
  title VARCHAR(250) NOT NULL,
  acquisition_date DATE NOT NULL,
  capitalization_date DATE NOT NULL,
  original_cost DECIMAL(20,2) NOT NULL,
  salvage_value DECIMAL(20,2) NOT NULL DEFAULT 0,
  useful_life_months INT NOT NULL,
  accumulated_depreciation DECIMAL(20,2) NOT NULL DEFAULT 0,
  net_book_value DECIMAL(20,2) NOT NULL,
  branch_id BIGINT UNSIGNED NULL,
  location VARCHAR(250) NULL,
  custodian_party_id BIGINT UNSIGNED NULL,
  status ENUM('DRAFT','ACTIVE','IDLE','UNDER_REPAIR','SOLD','DISPOSED','FULLY_DEPRECIATED') NOT NULL DEFAULT 'DRAFT',
  purchase_invoice_id BIGINT UNSIGNED NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_fixed_asset(company_id,asset_no),
  CONSTRAINT fk_fa_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_fa_class FOREIGN KEY(asset_class_id) REFERENCES fixed_asset_classes(id),
  CONSTRAINT fk_fa_branch FOREIGN KEY(branch_id) REFERENCES branches(id),
  CONSTRAINT fk_fa_custodian FOREIGN KEY(custodian_party_id) REFERENCES parties(id),
  CONSTRAINT fk_fa_purchase_invoice FOREIGN KEY(purchase_invoice_id) REFERENCES purchase_invoices(id),
  CONSTRAINT fk_fa_creator FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS fixed_asset_movements (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  fixed_asset_id BIGINT UNSIGNED NOT NULL,
  movement_date DATE NOT NULL,
  movement_type ENUM('CAPITALIZE','TRANSFER','REPAIR','IMPAIRMENT','SALE','DISPOSAL','REVALUE') NOT NULL,
  from_location VARCHAR(250) NULL,
  to_location VARCHAR(250) NULL,
  from_custodian_party_id BIGINT UNSIGNED NULL,
  to_custodian_party_id BIGINT UNSIGNED NULL,
  amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  journal_entry_id BIGINT UNSIGNED NULL,
  note VARCHAR(1000) NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_fam_asset FOREIGN KEY(fixed_asset_id) REFERENCES fixed_assets(id) ON DELETE CASCADE,
  CONSTRAINT fk_fam_journal FOREIGN KEY(journal_entry_id) REFERENCES journal_entries(id),
  CONSTRAINT fk_fam_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS depreciation_runs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  run_no VARCHAR(80) NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  status ENUM('DRAFT','CALCULATED','REVIEWED','POSTED','VOID') NOT NULL DEFAULT 'DRAFT',
  total_depreciation DECIMAL(20,2) NOT NULL DEFAULT 0,
  journal_entry_id BIGINT UNSIGNED NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  reviewed_by BIGINT UNSIGNED NULL,
  posted_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_dep_run(company_id,run_no),
  CONSTRAINT fk_dr_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_dr_journal FOREIGN KEY(journal_entry_id) REFERENCES journal_entries(id),
  CONSTRAINT fk_dr_creator FOREIGN KEY(created_by) REFERENCES users(id),
  CONSTRAINT fk_dr_reviewer FOREIGN KEY(reviewed_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS depreciation_run_lines (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  depreciation_run_id BIGINT UNSIGNED NOT NULL,
  fixed_asset_id BIGINT UNSIGNED NOT NULL,
  opening_nbv DECIMAL(20,2) NOT NULL,
  depreciation_amount DECIMAL(20,2) NOT NULL,
  closing_nbv DECIMAL(20,2) NOT NULL,
  UNIQUE KEY uq_dep_run_asset(depreciation_run_id,fixed_asset_id),
  CONSTRAINT fk_drl_run FOREIGN KEY(depreciation_run_id) REFERENCES depreciation_runs(id) ON DELETE CASCADE,
  CONSTRAINT fk_drl_asset FOREIGN KEY(fixed_asset_id) REFERENCES fixed_assets(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS landed_cost_headers (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  landed_cost_no VARCHAR(80) NOT NULL,
  cost_date DATE NOT NULL,
  title VARCHAR(250) NOT NULL,
  allocation_basis ENUM('VALUE','QUANTITY','WEIGHT','VOLUME','MANUAL') NOT NULL DEFAULT 'VALUE',
  total_cost DECIMAL(20,2) NOT NULL DEFAULT 0,
  status ENUM('DRAFT','CALCULATED','POSTED','VOID') NOT NULL DEFAULT 'DRAFT',
  journal_entry_id BIGINT UNSIGNED NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_landed_cost(company_id,landed_cost_no),
  CONSTRAINT fk_lch_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_lch_journal FOREIGN KEY(journal_entry_id) REFERENCES journal_entries(id),
  CONSTRAINT fk_lch_creator FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS landed_cost_sources (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  landed_cost_id BIGINT UNSIGNED NOT NULL,
  cost_type ENUM('FREIGHT','INSURANCE','CUSTOMS','LOADING','UNLOADING','HANDLING','OTHER') NOT NULL,
  amount DECIMAL(20,2) NOT NULL,
  supplier_party_id BIGINT UNSIGNED NULL,
  purchase_invoice_id BIGINT UNSIGNED NULL,
  expense_account_id BIGINT UNSIGNED NULL,
  note VARCHAR(500) NULL,
  CONSTRAINT fk_lcs_header FOREIGN KEY(landed_cost_id) REFERENCES landed_cost_headers(id) ON DELETE CASCADE,
  CONSTRAINT fk_lcs_supplier FOREIGN KEY(supplier_party_id) REFERENCES parties(id),
  CONSTRAINT fk_lcs_pi FOREIGN KEY(purchase_invoice_id) REFERENCES purchase_invoices(id),
  CONSTRAINT fk_lcs_exp_ac FOREIGN KEY(expense_account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS landed_cost_targets (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  landed_cost_id BIGINT UNSIGNED NOT NULL,
  goods_receipt_line_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  quantity DECIMAL(20,4) NOT NULL,
  base_value DECIMAL(20,2) NOT NULL,
  weight_value DECIMAL(20,4) NULL,
  volume_value DECIMAL(20,4) NULL,
  manual_weight DECIMAL(20,6) NULL,
  allocated_cost DECIMAL(20,2) NOT NULL DEFAULT 0,
  UNIQUE KEY uq_lct_grline(landed_cost_id,goods_receipt_line_id),
  CONSTRAINT fk_lct_header FOREIGN KEY(landed_cost_id) REFERENCES landed_cost_headers(id) ON DELETE CASCADE,
  CONSTRAINT fk_lct_grline FOREIGN KEY(goods_receipt_line_id) REFERENCES goods_receipt_lines(id),
  CONSTRAINT fk_lct_product FOREIGN KEY(product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS management_projects (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  project_code VARCHAR(80) NOT NULL,
  title VARCHAR(250) NOT NULL,
  customer_party_id BIGINT UNSIGNED NULL,
  manager_user_id BIGINT UNSIGNED NULL,
  start_date DATE NOT NULL,
  end_date DATE NULL,
  budget_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  status ENUM('PLANNED','ACTIVE','ON_HOLD','COMPLETED','CLOSED','CANCELLED') NOT NULL DEFAULT 'PLANNED',
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_project(company_id,project_code),
  CONSTRAINT fk_mp_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_mp_customer FOREIGN KEY(customer_party_id) REFERENCES parties(id),
  CONSTRAINT fk_mp_manager FOREIGN KEY(manager_user_id) REFERENCES users(id),
  CONSTRAINT fk_mp_creator FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS project_contracts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  project_id BIGINT UNSIGNED NOT NULL,
  contract_no VARCHAR(100) NOT NULL,
  contract_type ENUM('CUSTOMER','SUPPLIER','SUBCONTRACT') NOT NULL,
  counterparty_party_id BIGINT UNSIGNED NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NULL,
  contract_amount DECIMAL(20,2) NOT NULL,
  advance_percent DECIMAL(10,4) NOT NULL DEFAULT 0,
  retention_percent DECIMAL(10,4) NOT NULL DEFAULT 0,
  status ENUM('DRAFT','ACTIVE','SUSPENDED','COMPLETED','CLOSED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_project_contract(company_id,contract_no),
  CONSTRAINT fk_pc_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_pc_project FOREIGN KEY(project_id) REFERENCES management_projects(id),
  CONSTRAINT fk_pc_party FOREIGN KEY(counterparty_party_id) REFERENCES parties(id),
  CONSTRAINT fk_pc_creator FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS contract_milestones (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  project_contract_id BIGINT UNSIGNED NOT NULL,
  milestone_no VARCHAR(80) NOT NULL,
  title VARCHAR(250) NOT NULL,
  due_date DATE NULL,
  amount DECIMAL(20,2) NOT NULL,
  progress_percent DECIMAL(10,4) NOT NULL DEFAULT 0,
  billed_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  received_paid_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  status ENUM('PLANNED','IN_PROGRESS','READY_TO_BILL','BILLED','SETTLED','CLOSED') NOT NULL DEFAULT 'PLANNED',
  UNIQUE KEY uq_contract_milestone(project_contract_id,milestone_no),
  CONSTRAINT fk_cm_contract FOREIGN KEY(project_contract_id) REFERENCES project_contracts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS finance_reconciliation_snapshots (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  snapshot_date DATE NOT NULL,
  subledger_type ENUM('AR','AP','INVENTORY','PAYROLL','FIXED_ASSET','BANK') NOT NULL,
  subledger_amount DECIMAL(20,2) NOT NULL,
  gl_amount DECIMAL(20,2) NOT NULL,
  difference_amount DECIMAL(20,2) NOT NULL,
  status ENUM('BALANCED','DIFFERENCE') NOT NULL,
  details_json JSON NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_recon_snapshot(company_id,snapshot_date,subledger_type,status),
  CONSTRAINT fk_frs_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_frs_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'410200','برگشت و تخفیفات فروش',3,'DEBIT','REVENUE',1 FROM companies;
INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'140100','دارایی‌های ثابت مشهود',3,'DEBIT','ASSET',1 FROM companies;
INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'140200','استهلاک انباشته دارایی‌های ثابت',3,'CREDIT','ASSET',1 FROM companies;
INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'610400','هزینه استهلاک',3,'DEBIT','EXPENSE',1 FROM companies;
INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'210600','هزینه‌های خرید و حمل پرداختنی',3,'CREDIT','LIABILITY',1 FROM companies;
