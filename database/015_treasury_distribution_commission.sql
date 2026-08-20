-- TARAZPAD Enterprise 1.2: Treasury + DMS/POD + Commission

ALTER TABLE bank_accounts
  ADD COLUMN gl_account_id BIGINT UNSIGNED NULL AFTER opening_balance,
  ADD CONSTRAINT fk_bank_gl_account FOREIGN KEY(gl_account_id) REFERENCES accounts(id);

ALTER TABLE receipts
  ADD COLUMN bank_account_id BIGINT UNSIGNED NULL AFTER method,
  ADD COLUMN posting_date DATE NULL AFTER receipt_date,
  ADD COLUMN journal_entry_id BIGINT UNSIGNED NULL,
  ADD COLUMN source_type VARCHAR(80) NULL,
  ADD COLUMN source_id BIGINT UNSIGNED NULL,
  ADD COLUMN idempotency_key VARCHAR(100) NULL,
  ADD COLUMN notes VARCHAR(1000) NULL,
  ADD UNIQUE KEY uq_receipt_idempotency(company_id,idempotency_key),
  ADD KEY ix_receipt_bank(company_id,bank_account_id,receipt_date),
  ADD CONSTRAINT fk_receipt_bank FOREIGN KEY(bank_account_id) REFERENCES bank_accounts(id),
  ADD CONSTRAINT fk_receipt_journal FOREIGN KEY(journal_entry_id) REFERENCES journal_entries(id);

ALTER TABLE payments
  ADD COLUMN bank_account_id BIGINT UNSIGNED NULL AFTER method,
  ADD COLUMN posting_date DATE NULL AFTER payment_date,
  ADD COLUMN journal_entry_id BIGINT UNSIGNED NULL,
  ADD COLUMN source_type VARCHAR(80) NULL,
  ADD COLUMN source_id BIGINT UNSIGNED NULL,
  ADD COLUMN idempotency_key VARCHAR(100) NULL,
  ADD COLUMN notes VARCHAR(1000) NULL,
  ADD UNIQUE KEY uq_payment_idempotency(company_id,idempotency_key),
  ADD KEY ix_payment_bank(company_id,bank_account_id,payment_date),
  ADD CONSTRAINT fk_payment_bank FOREIGN KEY(bank_account_id) REFERENCES bank_accounts(id),
  ADD CONSTRAINT fk_payment_journal FOREIGN KEY(journal_entry_id) REFERENCES journal_entries(id);

CREATE TABLE IF NOT EXISTS treasury_account_settings (
  company_id BIGINT UNSIGNED PRIMARY KEY,
  default_bank_account_id BIGINT UNSIGNED NOT NULL,
  cash_account_id BIGINT UNSIGNED NOT NULL,
  pos_clearing_account_id BIGINT UNSIGNED NOT NULL,
  customer_advance_account_id BIGINT UNSIGNED NOT NULL,
  supplier_advance_account_id BIGINT UNSIGNED NOT NULL,
  bank_fee_account_id BIGINT UNSIGNED NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_tas_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_tas_bank FOREIGN KEY(default_bank_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_tas_cash FOREIGN KEY(cash_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_tas_pos FOREIGN KEY(pos_clearing_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_tas_customer_adv FOREIGN KEY(customer_advance_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_tas_supplier_adv FOREIGN KEY(supplier_advance_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_tas_fee FOREIGN KEY(bank_fee_account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS bank_reconciliation_matches (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  bank_statement_line_id BIGINT UNSIGNED NOT NULL,
  entity_type ENUM('RECEIPT','PAYMENT','POS_SETTLEMENT','CHEQUE','BANK_FEE','TRANSFER') NOT NULL,
  entity_id BIGINT UNSIGNED NOT NULL,
  matched_amount DECIMAL(20,2) NOT NULL,
  confidence_score DECIMAL(8,4) NULL,
  status ENUM('SUGGESTED','CONFIRMED','REVERSED') NOT NULL DEFAULT 'SUGGESTED',
  suggested_at DATETIME NULL,
  confirmed_at DATETIME NULL,
  confirmed_by BIGINT UNSIGNED NULL,
  reversed_at DATETIME NULL,
  reversed_by BIGINT UNSIGNED NULL,
  note VARCHAR(1000) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_brm_line(bank_statement_line_id,status),
  KEY ix_brm_entity(company_id,entity_type,entity_id,status),
  CONSTRAINT fk_brm_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_brm_line FOREIGN KEY(bank_statement_line_id) REFERENCES bank_statement_lines(id) ON DELETE CASCADE,
  CONSTRAINT fk_brm_confirm_user FOREIGN KEY(confirmed_by) REFERENCES users(id),
  CONSTRAINT fk_brm_reverse_user FOREIGN KEY(reversed_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS pos_terminals (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  bank_account_id BIGINT UNSIGNED NOT NULL,
  code VARCHAR(50) NOT NULL,
  title VARCHAR(200) NOT NULL,
  terminal_no VARCHAR(100) NULL,
  merchant_no VARCHAR(100) NULL,
  psp_name VARCHAR(120) NULL,
  settlement_lag_days INT NOT NULL DEFAULT 1,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_pos_terminal(company_id,code),
  CONSTRAINT fk_pos_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_pos_bank FOREIGN KEY(bank_account_id) REFERENCES bank_accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS pos_transactions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  terminal_id BIGINT UNSIGNED NOT NULL,
  transaction_date DATETIME NOT NULL,
  amount DECIMAL(20,2) NOT NULL,
  reference_no VARCHAR(120) NULL,
  trace_no VARCHAR(120) NULL,
  receipt_id BIGINT UNSIGNED NULL,
  status ENUM('CAPTURED','SETTLEMENT_PENDING','SETTLED','REVERSED','DISPUTED') NOT NULL DEFAULT 'CAPTURED',
  external_hash VARCHAR(128) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_pos_hash(company_id,terminal_id,external_hash),
  KEY ix_pos_tx_date(company_id,transaction_date,status),
  CONSTRAINT fk_postx_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_postx_terminal FOREIGN KEY(terminal_id) REFERENCES pos_terminals(id),
  CONSTRAINT fk_postx_receipt FOREIGN KEY(receipt_id) REFERENCES receipts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS pos_settlements (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  terminal_id BIGINT UNSIGNED NOT NULL,
  settlement_date DATE NOT NULL,
  gross_amount DECIMAL(20,2) NOT NULL,
  fee_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  net_amount DECIMAL(20,2) NOT NULL,
  bank_statement_line_id BIGINT UNSIGNED NULL,
  journal_entry_id BIGINT UNSIGNED NULL,
  status ENUM('PENDING','MATCHED','POSTED','RECONCILED','EXCEPTION') NOT NULL DEFAULT 'PENDING',
  reference_no VARCHAR(120) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_pos_settlement(company_id,settlement_date,status),
  CONSTRAINT fk_poss_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_poss_terminal FOREIGN KEY(terminal_id) REFERENCES pos_terminals(id),
  CONSTRAINT fk_poss_bank_line FOREIGN KEY(bank_statement_line_id) REFERENCES bank_statement_lines(id),
  CONSTRAINT fk_poss_journal FOREIGN KEY(journal_entry_id) REFERENCES journal_entries(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS payment_proposals (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  proposal_no VARCHAR(80) NOT NULL,
  proposal_date DATE NOT NULL,
  horizon_days INT NOT NULL DEFAULT 7,
  status ENUM('DRAFT','WAITING_APPROVAL','APPROVED','EXECUTING','COMPLETED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  total_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  created_by BIGINT UNSIGNED NOT NULL,
  approved_by BIGINT UNSIGNED NULL,
  approved_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_payment_proposal(company_id,proposal_no),
  CONSTRAINT fk_pprop_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_pprop_creator FOREIGN KEY(created_by) REFERENCES users(id),
  CONSTRAINT fk_pprop_approver FOREIGN KEY(approved_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS payment_proposal_lines (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  payment_proposal_id BIGINT UNSIGNED NOT NULL,
  purchase_invoice_id BIGINT UNSIGNED NOT NULL,
  supplier_party_id BIGINT UNSIGNED NOT NULL,
  due_date DATE NULL,
  outstanding_amount DECIMAL(20,2) NOT NULL,
  proposed_amount DECIMAL(20,2) NOT NULL,
  priority_score DECIMAL(10,4) NOT NULL DEFAULT 0,
  selected TINYINT(1) NOT NULL DEFAULT 1,
  payment_id BIGINT UNSIGNED NULL,
  note VARCHAR(500) NULL,
  UNIQUE KEY uq_pprop_invoice(payment_proposal_id,purchase_invoice_id),
  CONSTRAINT fk_ppl_prop FOREIGN KEY(payment_proposal_id) REFERENCES payment_proposals(id) ON DELETE CASCADE,
  CONSTRAINT fk_ppl_invoice FOREIGN KEY(purchase_invoice_id) REFERENCES purchase_invoices(id),
  CONSTRAINT fk_ppl_supplier FOREIGN KEY(supplier_party_id) REFERENCES parties(id),
  CONSTRAINT fk_ppl_payment FOREIGN KEY(payment_id) REFERENCES payments(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS cheque_status_history (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  cheque_id BIGINT UNSIGNED NOT NULL,
  old_status VARCHAR(40) NULL,
  new_status VARCHAR(40) NOT NULL,
  event_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  bank_account_id BIGINT UNSIGNED NULL,
  reference_no VARCHAR(120) NULL,
  note VARCHAR(500) NULL,
  changed_by BIGINT UNSIGNED NOT NULL,
  CONSTRAINT fk_csh_cheque FOREIGN KEY(cheque_id) REFERENCES cheques(id) ON DELETE CASCADE,
  CONSTRAINT fk_csh_bank FOREIGN KEY(bank_account_id) REFERENCES bank_accounts(id),
  CONSTRAINT fk_csh_user FOREIGN KEY(changed_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

ALTER TABLE trip_stops
  ADD COLUMN arrived_at DATETIME NULL,
  ADD COLUMN departed_at DATETIME NULL,
  ADD COLUMN pod_signature_ref VARCHAR(500) NULL,
  ADD COLUMN pod_photo_ref VARCHAR(500) NULL,
  ADD COLUMN delivery_note VARCHAR(1000) NULL,
  ADD COLUMN failure_reason VARCHAR(500) NULL;

CREATE TABLE IF NOT EXISTS trip_status_history (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  trip_id BIGINT UNSIGNED NOT NULL,
  old_status VARCHAR(40) NULL,
  new_status VARCHAR(40) NOT NULL,
  event_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  note VARCHAR(1000) NULL,
  latitude DECIMAL(10,7) NULL,
  longitude DECIMAL(10,7) NULL,
  changed_by BIGINT UNSIGNED NOT NULL,
  CONSTRAINT fk_tsh_trip FOREIGN KEY(trip_id) REFERENCES trips(id) ON DELETE CASCADE,
  CONSTRAINT fk_tsh_user FOREIGN KEY(changed_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS trip_stop_lines (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  trip_stop_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  planned_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  delivered_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  returned_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  damaged_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  note VARCHAR(500) NULL,
  UNIQUE KEY uq_trip_stop_product(trip_stop_id,product_id),
  CONSTRAINT fk_tsl_stop FOREIGN KEY(trip_stop_id) REFERENCES trip_stops(id) ON DELETE CASCADE,
  CONSTRAINT fk_tsl_product FOREIGN KEY(product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS trip_temperature_events (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  trip_id BIGINT UNSIGNED NOT NULL,
  trip_stop_id BIGINT UNSIGNED NULL,
  recorded_at DATETIME NOT NULL,
  temperature_c DECIMAL(8,3) NOT NULL,
  min_allowed_c DECIMAL(8,3) NULL,
  max_allowed_c DECIMAL(8,3) NULL,
  latitude DECIMAL(10,7) NULL,
  longitude DECIMAL(10,7) NULL,
  status ENUM('NORMAL','EXCURSION') NOT NULL DEFAULT 'NORMAL',
  note VARCHAR(500) NULL,
  recorded_by BIGINT UNSIGNED NOT NULL,
  KEY ix_temp_trip(trip_id,recorded_at,status),
  CONSTRAINT fk_tte_trip FOREIGN KEY(trip_id) REFERENCES trips(id) ON DELETE CASCADE,
  CONSTRAINT fk_tte_stop FOREIGN KEY(trip_stop_id) REFERENCES trip_stops(id) ON DELETE SET NULL,
  CONSTRAINT fk_tte_user FOREIGN KEY(recorded_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS trip_return_receipts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  trip_id BIGINT UNSIGNED NOT NULL,
  warehouse_id BIGINT UNSIGNED NOT NULL,
  return_date DATETIME NOT NULL,
  status ENUM('DRAFT','POSTED','VOID') NOT NULL DEFAULT 'DRAFT',
  created_by BIGINT UNSIGNED NOT NULL,
  posted_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_trr_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_trr_trip FOREIGN KEY(trip_id) REFERENCES trips(id),
  CONSTRAINT fk_trr_wh FOREIGN KEY(warehouse_id) REFERENCES warehouses(id),
  CONSTRAINT fk_trr_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS trip_return_receipt_lines (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  trip_return_receipt_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  quantity DECIMAL(20,4) NOT NULL,
  condition_code ENUM('SALEABLE','DAMAGED','EXPIRED','QUARANTINE') NOT NULL DEFAULT 'SALEABLE',
  batch_no VARCHAR(100) NULL,
  expiry_date DATE NULL,
  CONSTRAINT fk_trrl_header FOREIGN KEY(trip_return_receipt_id) REFERENCES trip_return_receipts(id) ON DELETE CASCADE,
  CONSTRAINT fk_trrl_product FOREIGN KEY(product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

ALTER TABLE trip_collections
  ADD COLUMN handed_over_by BIGINT UNSIGNED NULL,
  ADD COLUMN received_by BIGINT UNSIGNED NULL,
  ADD COLUMN handover_note VARCHAR(500) NULL,
  ADD CONSTRAINT fk_tc_handover_by FOREIGN KEY(handed_over_by) REFERENCES users(id),
  ADD CONSTRAINT fk_tc_received_by FOREIGN KEY(received_by) REFERENCES users(id);

CREATE TABLE IF NOT EXISTS vehicle_service_events (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  vehicle_id BIGINT UNSIGNED NOT NULL,
  event_type ENUM('FUEL','SERVICE','REPAIR','INSURANCE','INSPECTION','TYRE','OTHER') NOT NULL,
  event_date DATE NOT NULL,
  odometer DECIMAL(20,2) NULL,
  quantity DECIMAL(20,4) NULL,
  amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  next_due_date DATE NULL,
  next_due_odometer DECIMAL(20,2) NULL,
  supplier VARCHAR(200) NULL,
  reference_no VARCHAR(120) NULL,
  note VARCHAR(1000) NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_vse_due(company_id,vehicle_id,event_type,event_date),
  CONSTRAINT fk_vse_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_vse_vehicle FOREIGN KEY(vehicle_id) REFERENCES vehicles(id),
  CONSTRAINT fk_vse_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

ALTER TABLE sales_invoices
  ADD COLUMN salesperson_user_id BIGINT UNSIGNED NULL,
  ADD COLUMN sales_order_id BIGINT UNSIGNED NULL,
  ADD COLUMN route_id BIGINT UNSIGNED NULL,
  ADD CONSTRAINT fk_si_salesperson FOREIGN KEY(salesperson_user_id) REFERENCES users(id),
  ADD CONSTRAINT fk_si_order FOREIGN KEY(sales_order_id) REFERENCES sales_orders(id),
  ADD CONSTRAINT fk_si_route FOREIGN KEY(route_id) REFERENCES routes(id);

ALTER TABLE sales_invoice_lines
  ADD COLUMN unit_cost_snapshot DECIMAL(20,4) NOT NULL DEFAULT 0,
  ADD COLUMN cogs_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  ADD COLUMN gross_profit_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  ADD COLUMN brand_snapshot VARCHAR(120) NULL,
  ADD COLUMN category_snapshot VARCHAR(120) NULL;

ALTER TABLE commission_results
  MODIFY status ENUM('CALCULATED','REVIEWED','APPROVED','PAYABLE','PAYROLL_PENDING','PAID','CLAWED_BACK','VOID') NOT NULL DEFAULT 'CALCULATED',
  ADD COLUMN commission_rule_id BIGINT UNSIGNED NULL,
  ADD COLUMN target_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  ADD COLUMN achievement_pct DECIMAL(12,4) NOT NULL DEFAULT 0,
  ADD COLUMN collected_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  ADD COLUMN gross_profit_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  ADD COLUMN reviewed_by BIGINT UNSIGNED NULL,
  ADD COLUMN approved_by BIGINT UNSIGNED NULL,
  ADD COLUMN paid_at DATETIME NULL,
  ADD CONSTRAINT fk_comm_result_rule FOREIGN KEY(commission_rule_id) REFERENCES commission_rules(id),
  ADD CONSTRAINT fk_comm_review_user FOREIGN KEY(reviewed_by) REFERENCES users(id),
  ADD CONSTRAINT fk_comm_approve_user FOREIGN KEY(approved_by) REFERENCES users(id);

CREATE TABLE IF NOT EXISTS commission_targets (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  salesperson_user_id BIGINT UNSIGNED NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  target_type ENUM('NET_SALES','GROSS_PROFIT','COLLECTION','NEW_CUSTOMER') NOT NULL DEFAULT 'NET_SALES',
  target_amount DECIMAL(20,2) NOT NULL,
  UNIQUE KEY uq_comm_target(company_id,salesperson_user_id,period_start,period_end,target_type),
  CONSTRAINT fk_ct_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_ct_user FOREIGN KEY(salesperson_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS commission_result_lines (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  commission_result_id BIGINT UNSIGNED NOT NULL,
  sales_invoice_id BIGINT UNSIGNED NULL,
  receipt_allocation_id BIGINT UNSIGNED NULL,
  source_date DATE NOT NULL,
  gross_sales DECIMAL(20,2) NOT NULL DEFAULT 0,
  net_sales DECIMAL(20,2) NOT NULL DEFAULT 0,
  collected_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  cogs_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  gross_profit_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  eligible_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  commission_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  adjustment_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  detail_json JSON NULL,
  KEY ix_crl_result(commission_result_id,source_date),
  KEY ix_crl_invoice(sales_invoice_id),
  CONSTRAINT fk_crl_result FOREIGN KEY(commission_result_id) REFERENCES commission_results(id) ON DELETE CASCADE,
  CONSTRAINT fk_crl_invoice FOREIGN KEY(sales_invoice_id) REFERENCES sales_invoices(id),
  CONSTRAINT fk_crl_receipt_alloc FOREIGN KEY(receipt_allocation_id) REFERENCES receipt_allocations(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS commission_adjustments (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  salesperson_user_id BIGINT UNSIGNED NOT NULL,
  sales_invoice_id BIGINT UNSIGNED NULL,
  adjustment_date DATE NOT NULL,
  adjustment_type ENUM('RETURN','CANCELLATION','BAD_DEBT','CREDIT_NOTE','MANUAL_BONUS','MANUAL_PENALTY') NOT NULL,
  amount DECIMAL(20,2) NOT NULL,
  reason VARCHAR(1000) NOT NULL,
  status ENUM('DRAFT','APPROVED','APPLIED','VOID') NOT NULL DEFAULT 'DRAFT',
  created_by BIGINT UNSIGNED NOT NULL,
  approved_by BIGINT UNSIGNED NULL,
  approved_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_cadj_user(company_id,salesperson_user_id,adjustment_date,status),
  CONSTRAINT fk_cadj_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_cadj_user FOREIGN KEY(salesperson_user_id) REFERENCES users(id),
  CONSTRAINT fk_cadj_invoice FOREIGN KEY(sales_invoice_id) REFERENCES sales_invoices(id),
  CONSTRAINT fk_cadj_creator FOREIGN KEY(created_by) REFERENCES users(id),
  CONSTRAINT fk_cadj_approver FOREIGN KEY(approved_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Default treasury accounts; configurable per company and not hard-coded in posting logic.
INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'110200','بانک‌ها',3,'DEBIT','ASSET',1 FROM companies;
INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'110210','صندوق و وجوه نقد',3,'DEBIT','ASSET',1 FROM companies;
INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'110220','وجوه در راه و تسویه کارتخوان',3,'DEBIT','ASSET',1 FROM companies;
INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'210500','پیش‌دریافت از مشتریان',3,'CREDIT','LIABILITY',1 FROM companies;
INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'120500','پیش‌پرداخت به تأمین‌کنندگان',3,'DEBIT','ASSET',1 FROM companies;
INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'610300','کارمزد و هزینه‌های بانکی',3,'DEBIT','EXPENSE',1 FROM companies;

INSERT IGNORE INTO treasury_account_settings(company_id,default_bank_account_id,cash_account_id,pos_clearing_account_id,customer_advance_account_id,supplier_advance_account_id,bank_fee_account_id)
SELECT c.id,b.id,cash.id,pos.id,cadv.id,sadv.id,fee.id
FROM companies c
JOIN accounts b ON b.company_id=c.id AND b.code='110200'
JOIN accounts cash ON cash.company_id=c.id AND cash.code='110210'
JOIN accounts pos ON pos.company_id=c.id AND pos.code='110220'
JOIN accounts cadv ON cadv.company_id=c.id AND cadv.code='210500'
JOIN accounts sadv ON sadv.company_id=c.id AND sadv.code='120500'
JOIN accounts fee ON fee.company_id=c.id AND fee.code='610300';

UPDATE bank_accounts ba
JOIN accounts a ON a.company_id=ba.company_id AND a.code='110200'
SET ba.gl_account_id=a.id
WHERE ba.gl_account_id IS NULL;
