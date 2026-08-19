CREATE TABLE IF NOT EXISTS permissions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(100) NOT NULL UNIQUE,
  title VARCHAR(200) NOT NULL,
  module_code VARCHAR(80) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS role_permissions (
  role_id BIGINT UNSIGNED NOT NULL,
  permission_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY(role_id,permission_id),
  CONSTRAINT fk_rp_role FOREIGN KEY(role_id) REFERENCES roles(id) ON DELETE CASCADE,
  CONSTRAINT fk_rp_permission FOREIGN KEY(permission_id) REFERENCES permissions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS document_sequences (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  branch_id BIGINT UNSIGNED NULL,
  fiscal_year_id BIGINT UNSIGNED NULL,
  document_type VARCHAR(80) NOT NULL,
  prefix VARCHAR(30) NOT NULL,
  last_number BIGINT UNSIGNED NOT NULL DEFAULT 0,
  pad_length TINYINT UNSIGNED NOT NULL DEFAULT 6,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_doc_seq(company_id,branch_id,fiscal_year_id,document_type),
  CONSTRAINT fk_seq_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_seq_branch FOREIGN KEY(branch_id) REFERENCES branches(id),
  CONSTRAINT fk_seq_fy FOREIGN KEY(fiscal_year_id) REFERENCES fiscal_years(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS cost_centers (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  code VARCHAR(50) NOT NULL,
  title VARCHAR(200) NOT NULL,
  parent_id BIGINT UNSIGNED NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_cost_center(company_id,code),
  CONSTRAINT fk_cc_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_cc_parent FOREIGN KEY(parent_id) REFERENCES cost_centers(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS projects (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  code VARCHAR(50) NOT NULL,
  title VARCHAR(250) NOT NULL,
  start_date DATE NULL,
  end_date DATE NULL,
  budget_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  status ENUM('PLANNED','ACTIVE','ON_HOLD','COMPLETED','CANCELLED') NOT NULL DEFAULT 'PLANNED',
  UNIQUE KEY uq_project(company_id,code),
  CONSTRAINT fk_project_company FOREIGN KEY(company_id) REFERENCES companies(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS bank_accounts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  branch_id BIGINT UNSIGNED NULL,
  code VARCHAR(50) NOT NULL,
  bank_name VARCHAR(120) NOT NULL,
  account_title VARCHAR(200) NOT NULL,
  account_no VARCHAR(80) NULL,
  iban VARCHAR(40) NULL,
  card_no VARCHAR(30) NULL,
  currency CHAR(3) NOT NULL DEFAULT 'IRR',
  opening_balance DECIMAL(20,2) NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_bank_account(company_id,code),
  KEY ix_bank_iban(company_id,iban),
  CONSTRAINT fk_bank_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_bank_branch FOREIGN KEY(branch_id) REFERENCES branches(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS bank_statement_lines (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  bank_account_id BIGINT UNSIGNED NOT NULL,
  statement_date DATETIME NOT NULL,
  value_date DATETIME NULL,
  reference_no VARCHAR(120) NULL,
  description VARCHAR(500) NULL,
  debit DECIMAL(20,2) NOT NULL DEFAULT 0,
  credit DECIMAL(20,2) NOT NULL DEFAULT 0,
  running_balance DECIMAL(20,2) NULL,
  external_hash VARCHAR(128) NULL,
  match_status ENUM('UNMATCHED','SUGGESTED','MATCHED','IGNORED') NOT NULL DEFAULT 'UNMATCHED',
  matched_entity_type VARCHAR(80) NULL,
  matched_entity_id BIGINT UNSIGNED NULL,
  imported_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_bank_line_hash(company_id,bank_account_id,external_hash),
  KEY ix_bank_line_match(company_id,match_status,statement_date),
  CONSTRAINT fk_bank_line_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_bank_line_account FOREIGN KEY(bank_account_id) REFERENCES bank_accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS cheques (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  cheque_type ENUM('RECEIVABLE','PAYABLE') NOT NULL,
  cheque_no VARCHAR(100) NOT NULL,
  party_id BIGINT UNSIGNED NULL,
  bank_name VARCHAR(120) NULL,
  amount DECIMAL(20,2) NOT NULL,
  issue_date DATE NULL,
  due_date DATE NOT NULL,
  status ENUM('RECEIVED','IN_SAFE','DEPOSITED','COLLECTED','BOUNCED','ENDORSED','RETURNED','ISSUED','DELIVERED','CLEARED','CANCELLED') NOT NULL,
  reference_no VARCHAR(120) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_cheque_due(company_id,cheque_type,due_date,status),
  CONSTRAINT fk_cheque_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_cheque_party FOREIGN KEY(party_id) REFERENCES parties(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS receipt_allocations (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  receipt_id BIGINT UNSIGNED NOT NULL,
  sales_invoice_id BIGINT UNSIGNED NOT NULL,
  allocated_amount DECIMAL(20,2) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_receipt_invoice(receipt_id,sales_invoice_id),
  CONSTRAINT fk_ra_receipt FOREIGN KEY(receipt_id) REFERENCES receipts(id) ON DELETE CASCADE,
  CONSTRAINT fk_ra_invoice FOREIGN KEY(sales_invoice_id) REFERENCES sales_invoices(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS payment_allocations (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  payment_id BIGINT UNSIGNED NOT NULL,
  purchase_invoice_id BIGINT UNSIGNED NOT NULL,
  allocated_amount DECIMAL(20,2) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_payment_invoice(payment_id,purchase_invoice_id),
  CONSTRAINT fk_pa_payment FOREIGN KEY(payment_id) REFERENCES payments(id) ON DELETE CASCADE,
  CONSTRAINT fk_pa_invoice FOREIGN KEY(purchase_invoice_id) REFERENCES purchase_invoices(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sales_orders (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  branch_id BIGINT UNSIGNED NULL,
  order_no VARCHAR(80) NOT NULL,
  order_date DATE NOT NULL,
  customer_party_id BIGINT UNSIGNED NOT NULL,
  salesperson_user_id BIGINT UNSIGNED NULL,
  warehouse_id BIGINT UNSIGNED NULL,
  requested_delivery_date DATE NULL,
  payment_terms_days INT NOT NULL DEFAULT 0,
  status ENUM('DRAFT','WAITING_APPROVAL','APPROVED','CREDIT_HOLD','RESERVED','PARTIAL_RESERVED','READY','PARTIAL_DELIVERED','DELIVERED','CANCELLED','CLOSED') NOT NULL DEFAULT 'DRAFT',
  gross_total DECIMAL(20,2) NOT NULL DEFAULT 0,
  discount_total DECIMAL(20,2) NOT NULL DEFAULT 0,
  tax_total DECIMAL(20,2) NOT NULL DEFAULT 0,
  net_total DECIMAL(20,2) NOT NULL DEFAULT 0,
  credit_exposure_at_order DECIMAL(20,2) NOT NULL DEFAULT 0,
  override_reason VARCHAR(500) NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_sales_order(company_id,order_no),
  KEY ix_so_customer(company_id,customer_party_id,status),
  CONSTRAINT fk_so_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_so_branch FOREIGN KEY(branch_id) REFERENCES branches(id),
  CONSTRAINT fk_so_customer FOREIGN KEY(customer_party_id) REFERENCES parties(id),
  CONSTRAINT fk_so_salesperson FOREIGN KEY(salesperson_user_id) REFERENCES users(id),
  CONSTRAINT fk_so_warehouse FOREIGN KEY(warehouse_id) REFERENCES warehouses(id),
  CONSTRAINT fk_so_creator FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sales_order_lines (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sales_order_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  qty DECIMAL(20,4) NOT NULL,
  reserved_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  delivered_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  unit_price DECIMAL(20,2) NOT NULL,
  standard_price DECIMAL(20,2) NOT NULL DEFAULT 0,
  discount_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  tax_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  line_total DECIMAL(20,2) NOT NULL,
  override_reason VARCHAR(500) NULL,
  CONSTRAINT fk_sol_order FOREIGN KEY(sales_order_id) REFERENCES sales_orders(id) ON DELETE CASCADE,
  CONSTRAINT fk_sol_product FOREIGN KEY(product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS stock_reservations (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  warehouse_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  sales_order_line_id BIGINT UNSIGNED NOT NULL,
  quantity DECIMAL(20,4) NOT NULL,
  status ENUM('ACTIVE','PARTIALLY_CONSUMED','CONSUMED','RELEASED') NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_reservation_product(company_id,warehouse_id,product_id,status),
  CONSTRAINT fk_sr_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_sr_wh FOREIGN KEY(warehouse_id) REFERENCES warehouses(id),
  CONSTRAINT fk_sr_product FOREIGN KEY(product_id) REFERENCES products(id),
  CONSTRAINT fk_sr_line FOREIGN KEY(sales_order_line_id) REFERENCES sales_order_lines(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS purchase_orders (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  branch_id BIGINT UNSIGNED NULL,
  po_no VARCHAR(80) NOT NULL,
  po_date DATE NOT NULL,
  supplier_party_id BIGINT UNSIGNED NOT NULL,
  warehouse_id BIGINT UNSIGNED NULL,
  expected_date DATE NULL,
  status ENUM('DRAFT','WAITING_APPROVAL','APPROVED','SENT','CONFIRMED','PARTIAL_RECEIVED','RECEIVED','CANCELLED','CLOSED') NOT NULL DEFAULT 'DRAFT',
  gross_total DECIMAL(20,2) NOT NULL DEFAULT 0,
  discount_total DECIMAL(20,2) NOT NULL DEFAULT 0,
  tax_total DECIMAL(20,2) NOT NULL DEFAULT 0,
  net_total DECIMAL(20,2) NOT NULL DEFAULT 0,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_po(company_id,po_no),
  KEY ix_po_supplier(company_id,supplier_party_id,status),
  CONSTRAINT fk_po_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_po_branch FOREIGN KEY(branch_id) REFERENCES branches(id),
  CONSTRAINT fk_po_supplier FOREIGN KEY(supplier_party_id) REFERENCES parties(id),
  CONSTRAINT fk_po_wh FOREIGN KEY(warehouse_id) REFERENCES warehouses(id),
  CONSTRAINT fk_po_creator FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS purchase_order_lines (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  purchase_order_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  ordered_qty DECIMAL(20,4) NOT NULL,
  received_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  invoiced_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  unit_price DECIMAL(20,2) NOT NULL,
  discount_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  tax_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  line_total DECIMAL(20,2) NOT NULL,
  CONSTRAINT fk_pol_po FOREIGN KEY(purchase_order_id) REFERENCES purchase_orders(id) ON DELETE CASCADE,
  CONSTRAINT fk_pol_product FOREIGN KEY(product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS goods_receipts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  receipt_no VARCHAR(80) NOT NULL,
  receipt_date DATETIME NOT NULL,
  purchase_order_id BIGINT UNSIGNED NULL,
  supplier_party_id BIGINT UNSIGNED NULL,
  warehouse_id BIGINT UNSIGNED NOT NULL,
  qc_status ENUM('PENDING','ACCEPTED','CONDITIONAL','REJECTED','QUARANTINE') NOT NULL DEFAULT 'PENDING',
  status ENUM('DRAFT','RECEIVED','QC','PUTAWAY','CLOSED','VOID') NOT NULL DEFAULT 'DRAFT',
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_gr(company_id,receipt_no),
  CONSTRAINT fk_gr_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_gr_po FOREIGN KEY(purchase_order_id) REFERENCES purchase_orders(id),
  CONSTRAINT fk_gr_supplier FOREIGN KEY(supplier_party_id) REFERENCES parties(id),
  CONSTRAINT fk_gr_wh FOREIGN KEY(warehouse_id) REFERENCES warehouses(id),
  CONSTRAINT fk_gr_creator FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS goods_receipt_lines (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  goods_receipt_id BIGINT UNSIGNED NOT NULL,
  purchase_order_line_id BIGINT UNSIGNED NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  received_qty DECIMAL(20,4) NOT NULL,
  accepted_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  rejected_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  unit_cost DECIMAL(20,4) NOT NULL DEFAULT 0,
  batch_no VARCHAR(100) NULL,
  expiry_date DATE NULL,
  CONSTRAINT fk_grl_gr FOREIGN KEY(goods_receipt_id) REFERENCES goods_receipts(id) ON DELETE CASCADE,
  CONSTRAINT fk_grl_pol FOREIGN KEY(purchase_order_line_id) REFERENCES purchase_order_lines(id),
  CONSTRAINT fk_grl_product FOREIGN KEY(product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS approval_requests (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  entity_type VARCHAR(80) NOT NULL,
  entity_id BIGINT UNSIGNED NOT NULL,
  workflow_code VARCHAR(80) NOT NULL,
  status ENUM('PENDING','APPROVED','REJECTED','RETURNED','CANCELLED') NOT NULL DEFAULT 'PENDING',
  requested_by BIGINT UNSIGNED NOT NULL,
  requested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at DATETIME NULL,
  UNIQUE KEY uq_approval_entity(company_id,entity_type,entity_id,workflow_code,status),
  KEY ix_approval_pending(company_id,status,requested_at),
  CONSTRAINT fk_arq_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_arq_requester FOREIGN KEY(requested_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS approval_actions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  approval_request_id BIGINT UNSIGNED NOT NULL,
  actor_user_id BIGINT UNSIGNED NOT NULL,
  action ENUM('SUBMIT','APPROVE','REJECT','RETURN','REQUEST_INFO','REASSIGN') NOT NULL,
  note VARCHAR(1000) NULL,
  acted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_aa_request FOREIGN KEY(approval_request_id) REFERENCES approval_requests(id) ON DELETE CASCADE,
  CONSTRAINT fk_aa_actor FOREIGN KEY(actor_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS route_customers (
  route_id BIGINT UNSIGNED NOT NULL,
  customer_party_id BIGINT UNSIGNED NOT NULL,
  sequence_no INT NOT NULL DEFAULT 0,
  visit_frequency VARCHAR(50) NULL,
  delivery_window_from TIME NULL,
  delivery_window_to TIME NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY(route_id,customer_party_id),
  CONSTRAINT fk_rc_route FOREIGN KEY(route_id) REFERENCES routes(id) ON DELETE CASCADE,
  CONSTRAINT fk_rc_customer FOREIGN KEY(customer_party_id) REFERENCES parties(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS trip_load_lines (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  trip_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  warehouse_id BIGINT UNSIGNED NOT NULL,
  loaded_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  delivered_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  returned_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  damaged_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  variance_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  UNIQUE KEY uq_trip_load_product(trip_id,product_id,warehouse_id),
  CONSTRAINT fk_tll_trip FOREIGN KEY(trip_id) REFERENCES trips(id) ON DELETE CASCADE,
  CONSTRAINT fk_tll_product FOREIGN KEY(product_id) REFERENCES products(id),
  CONSTRAINT fk_tll_wh FOREIGN KEY(warehouse_id) REFERENCES warehouses(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS trip_collections (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  trip_id BIGINT UNSIGNED NOT NULL,
  customer_party_id BIGINT UNSIGNED NULL,
  receipt_id BIGINT UNSIGNED NULL,
  method ENUM('CASH','BANK','POS','CHEQUE','TRANSFER') NOT NULL,
  amount DECIMAL(20,2) NOT NULL,
  reference_no VARCHAR(120) NULL,
  handed_over_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_tc_trip FOREIGN KEY(trip_id) REFERENCES trips(id) ON DELETE CASCADE,
  CONSTRAINT fk_tc_party FOREIGN KEY(customer_party_id) REFERENCES parties(id),
  CONSTRAINT fk_tc_receipt FOREIGN KEY(receipt_id) REFERENCES receipts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS trip_expenses (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  trip_id BIGINT UNSIGNED NOT NULL,
  expense_type ENUM('FUEL','TOLL','PARKING','LOADING','UNLOADING','REPAIR','OTHER') NOT NULL,
  amount DECIMAL(20,2) NOT NULL,
  description VARCHAR(500) NULL,
  reference_no VARCHAR(120) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_te_trip FOREIGN KEY(trip_id) REFERENCES trips(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS commission_rule_tiers (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  commission_rule_id BIGINT UNSIGNED NOT NULL,
  threshold_from DECIMAL(20,2) NOT NULL DEFAULT 0,
  threshold_to DECIMAL(20,2) NULL,
  rate DECIMAL(10,4) NOT NULL,
  fixed_bonus DECIMAL(20,2) NOT NULL DEFAULT 0,
  UNIQUE KEY uq_comm_tier(commission_rule_id,threshold_from),
  CONSTRAINT fk_crt_rule FOREIGN KEY(commission_rule_id) REFERENCES commission_rules(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS commission_assignments (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  commission_rule_id BIGINT UNSIGNED NOT NULL,
  salesperson_user_id BIGINT UNSIGNED NOT NULL,
  effective_from DATE NOT NULL,
  effective_to DATE NULL,
  UNIQUE KEY uq_comm_assignment(company_id,commission_rule_id,salesperson_user_id,effective_from),
  CONSTRAINT fk_ca_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_ca_rule FOREIGN KEY(commission_rule_id) REFERENCES commission_rules(id),
  CONSTRAINT fk_ca_user FOREIGN KEY(salesperson_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS control_exceptions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  exception_code VARCHAR(80) NOT NULL,
  severity ENUM('INFO','WARNING','HIGH','CRITICAL') NOT NULL DEFAULT 'WARNING',
  entity_type VARCHAR(80) NULL,
  entity_id BIGINT UNSIGNED NULL,
  title VARCHAR(250) NOT NULL,
  details_json JSON NULL,
  status ENUM('OPEN','ACKNOWLEDGED','RESOLVED','IGNORED') NOT NULL DEFAULT 'OPEN',
  detected_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  resolved_at DATETIME NULL,
  resolved_by BIGINT UNSIGNED NULL,
  KEY ix_exception_open(company_id,status,severity,detected_at),
  CONSTRAINT fk_ce_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_ce_resolver FOREIGN KEY(resolved_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT IGNORE INTO permissions(code,title,module_code) VALUES
('FINANCE.VIEW','مشاهده مالی','FINANCE'),('FINANCE.POST','ثبت قطعی اسناد','FINANCE'),('TREASURY.MANAGE','مدیریت خزانه','TREASURY'),
('SALES.MANAGE','مدیریت فروش','SALES'),('SALES.APPROVE','تأیید فروش','SALES'),('INVENTORY.MANAGE','مدیریت انبار','INVENTORY'),
('PURCHASE.MANAGE','مدیریت خرید','PURCHASE'),('LOGISTICS.MANAGE','مدیریت لجستیک','LOGISTICS'),('WORKFLOW.APPROVE','تأیید گردش کار','WORKFLOW'),
('AUDIT.VIEW','مشاهده کنترل و حسابرسی','AUDIT');