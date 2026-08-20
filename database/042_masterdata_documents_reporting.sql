-- TARAZPAD Enterprise 1.8: detailed master data, commercial documents and print/report models

CREATE TABLE IF NOT EXISTS product_groups (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  parent_id BIGINT UNSIGNED NULL,
  code VARCHAR(50) NOT NULL,
  title VARCHAR(180) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_product_group(company_id,code),
  KEY ix_product_group_parent(company_id,parent_id,sort_order),
  CONSTRAINT fk_pgrp_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_pgrp_parent FOREIGN KEY(parent_id) REFERENCES product_groups(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS group_id BIGINT UNSIGNED NULL,
  ADD COLUMN IF NOT EXISTS image_ref VARCHAR(500) NULL,
  ADD COLUMN IF NOT EXISTS description TEXT NULL,
  ADD COLUMN IF NOT EXISTS sale_unit VARCHAR(40) NULL,
  ADD COLUMN IF NOT EXISTS purchase_unit VARCHAR(40) NULL,
  ADD COLUMN IF NOT EXISTS pack_qty DECIMAL(20,4) NULL,
  ADD COLUMN IF NOT EXISTS weight_net DECIMAL(20,4) NULL,
  ADD COLUMN IF NOT EXISTS weight_gross DECIMAL(20,4) NULL,
  ADD COLUMN IF NOT EXISTS country_of_origin VARCHAR(100) NULL,
  ADD COLUMN IF NOT EXISTS manufacturer VARCHAR(180) NULL,
  ADD COLUMN IF NOT EXISTS commission_pct DECIMAL(10,4) NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS product_opening_balances (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  fiscal_year_id BIGINT UNSIGNED NULL,
  warehouse_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  opening_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  opening_unit_cost DECIMAL(20,4) NOT NULL DEFAULT 0,
  opening_value DECIMAL(20,2) GENERATED ALWAYS AS (opening_qty*opening_unit_cost) STORED,
  batch_no VARCHAR(100) NULL,
  expiry_date DATE NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_product_opening(company_id,fiscal_year_id,warehouse_id,product_id,batch_no,expiry_date),
  CONSTRAINT fk_pob_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_pob_fy FOREIGN KEY(fiscal_year_id) REFERENCES fiscal_years(id),
  CONSTRAINT fk_pob_wh FOREIGN KEY(warehouse_id) REFERENCES warehouses(id),
  CONSTRAINT fk_pob_product FOREIGN KEY(product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS product_unit_conversions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_id BIGINT UNSIGNED NOT NULL,
  unit_name VARCHAR(50) NOT NULL,
  factor_to_base DECIMAL(20,6) NOT NULL DEFAULT 1,
  barcode VARCHAR(120) NULL,
  is_purchase_unit TINYINT(1) NOT NULL DEFAULT 0,
  is_sale_unit TINYINT(1) NOT NULL DEFAULT 0,
  UNIQUE KEY uq_product_unit(product_id,unit_name),
  CONSTRAINT fk_puc_product FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS service_profiles (
  product_id BIGINT UNSIGNED PRIMARY KEY,
  service_group VARCHAR(150) NULL,
  commission_pct DECIMAL(10,4) NOT NULL DEFAULT 0,
  duration_minutes INT NULL,
  is_taxable TINYINT(1) NOT NULL DEFAULT 1,
  notes VARCHAR(1000) NULL,
  CONSTRAINT fk_service_product FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS party_groups (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  parent_id BIGINT UNSIGNED NULL,
  code VARCHAR(50) NOT NULL,
  title VARCHAR(180) NOT NULL,
  group_type ENUM('GENERAL','CUSTOMER','SUPPLIER','EMPLOYEE','SHAREHOLDER','SALESPERSON','DRIVER','TECHNICIAN','CONTRACTOR','AGENT','OTHER') NOT NULL DEFAULT 'GENERAL',
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  sort_order INT NOT NULL DEFAULT 0,
  UNIQUE KEY uq_party_group(company_id,code),
  CONSTRAINT fk_partygrp_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_partygrp_parent FOREIGN KEY(parent_id) REFERENCES party_groups(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS party_group_memberships (
  party_id BIGINT UNSIGNED NOT NULL,
  party_group_id BIGINT UNSIGNED NOT NULL,
  is_primary TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY(party_id,party_group_id),
  CONSTRAINT fk_pgm_party FOREIGN KEY(party_id) REFERENCES parties(id) ON DELETE CASCADE,
  CONSTRAINT fk_pgm_group FOREIGN KEY(party_group_id) REFERENCES party_groups(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

ALTER TABLE parties
  ADD COLUMN IF NOT EXISTS prefix_title VARCHAR(40) NULL,
  ADD COLUMN IF NOT EXISTS first_name VARCHAR(120) NULL,
  ADD COLUMN IF NOT EXISTS last_name VARCHAR(150) NULL,
  ADD COLUMN IF NOT EXISTS company_name VARCHAR(250) NULL,
  ADD COLUMN IF NOT EXISTS image_ref VARCHAR(500) NULL,
  ADD COLUMN IF NOT EXISTS is_vip TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS opening_balance DECIMAL(20,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS opening_balance_nature ENUM('DEBIT','CREDIT','ZERO') NOT NULL DEFAULT 'ZERO',
  ADD COLUMN IF NOT EXISTS cash_credit_limit DECIMAL(20,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cheque_credit_limit DECIMAL(20,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS overall_credit_limit DECIMAL(20,2) NOT NULL DEFAULT 0;

ALTER TABLE bank_accounts
  ADD COLUMN IF NOT EXISTS account_type ENUM('CURRENT','SAVINGS','DEPOSIT','SHORT_TERM','LONG_TERM','LOAN','OTHER') NOT NULL DEFAULT 'CURRENT',
  ADD COLUMN IF NOT EXISTS bank_branch_name VARCHAR(180) NULL,
  ADD COLUMN IF NOT EXISTS bank_branch_code VARCHAR(50) NULL,
  ADD COLUMN IF NOT EXISTS account_holder VARCHAR(180) NULL,
  ADD COLUMN IF NOT EXISTS bank_phone VARCHAR(50) NULL,
  ADD COLUMN IF NOT EXISTS card_expiry VARCHAR(10) NULL,
  ADD COLUMN IF NOT EXISTS notes VARCHAR(1000) NULL;

CREATE TABLE IF NOT EXISTS price_lists (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  code VARCHAR(60) NOT NULL,
  title VARCHAR(200) NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'IRR',
  valid_from DATE NULL,
  valid_to DATE NULL,
  status ENUM('DRAFT','ACTIVE','EXPIRED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  channel VARCHAR(80) NULL,
  customer_group_id BIGINT UNSIGNED NULL,
  notes VARCHAR(1000) NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_price_list(company_id,code),
  KEY ix_price_list_active(company_id,status,valid_from,valid_to),
  CONSTRAINT fk_pl_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_pl_group FOREIGN KEY(customer_group_id) REFERENCES party_groups(id),
  CONSTRAINT fk_pl_creator FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS price_list_items (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  price_list_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  sale_price DECIMAL(20,2) NOT NULL,
  min_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  max_qty DECIMAL(20,4) NULL,
  promotional_price DECIMAL(20,2) NULL,
  notes VARCHAR(500) NULL,
  UNIQUE KEY uq_price_list_item(price_list_id,product_id,min_qty),
  CONSTRAINT fk_pli_list FOREIGN KEY(price_list_id) REFERENCES price_lists(id) ON DELETE CASCADE,
  CONSTRAINT fk_pli_product FOREIGN KEY(product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS print_profiles (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  document_type ENUM('SALES_INVOICE','PURCHASE_INVOICE','WAYBILL','PRICE_LIST','PICK_LIST','DELIVERY_NOTE','RECEIPT') NOT NULL,
  code VARCHAR(60) NOT NULL,
  title VARCHAR(180) NOT NULL,
  page_size ENUM('A4','A5','ROLL_80','CUSTOM') NOT NULL DEFAULT 'A4',
  logo_ref VARCHAR(500) NULL,
  header_text VARCHAR(1000) NULL,
  footer_text VARCHAR(1000) NULL,
  show_barcode TINYINT(1) NOT NULL DEFAULT 1,
  show_qr TINYINT(1) NOT NULL DEFAULT 1,
  show_signature_boxes TINYINT(1) NOT NULL DEFAULT 1,
  settings_json JSON NULL,
  is_default TINYINT(1) NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_print_profile(company_id,document_type,code),
  CONSTRAINT fk_print_company FOREIGN KEY(company_id) REFERENCES companies(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS waybills (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  waybill_no VARCHAR(80) NOT NULL,
  waybill_date DATE NOT NULL,
  trip_id BIGINT UNSIGNED NULL,
  trip_stop_id BIGINT UNSIGNED NULL,
  sales_invoice_id BIGINT UNSIGNED NULL,
  sender_party_id BIGINT UNSIGNED NULL,
  receiver_party_id BIGINT UNSIGNED NULL,
  sender_name VARCHAR(250) NULL,
  receiver_name VARCHAR(250) NULL,
  sender_phone VARCHAR(50) NULL,
  receiver_phone VARCHAR(50) NULL,
  sender_address TEXT NULL,
  receiver_address TEXT NULL,
  origin_city VARCHAR(120) NULL,
  destination_city VARCHAR(120) NULL,
  cargo_description VARCHAR(500) NULL,
  package_count DECIMAL(20,4) NOT NULL DEFAULT 0,
  gross_weight DECIMAL(20,4) NOT NULL DEFAULT 0,
  declared_value DECIMAL(20,2) NOT NULL DEFAULT 0,
  freight_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  insurance_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  loading_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  unloading_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  toll_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  other_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  total_charge DECIMAL(20,2) GENERATED ALWAYS AS (freight_amount+insurance_amount+loading_amount+unloading_amount+toll_amount+other_amount) STORED,
  payment_method ENUM('CASH','CREDIT','BANK','POS','CHEQUE','TRANSFER','OTHER') NOT NULL DEFAULT 'CREDIT',
  barcode_value VARCHAR(120) NULL,
  status ENUM('DRAFT','READY','DISPATCHED','IN_ROUTE','DELIVERED','PARTIAL','FAILED','RETURNED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  receiver_confirmed_name VARCHAR(200) NULL,
  received_at DATETIME NULL,
  receiver_signature_ref VARCHAR(500) NULL,
  driver_signature_ref VARCHAR(500) NULL,
  notes TEXT NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_waybill(company_id,waybill_no),
  KEY ix_waybill_date(company_id,waybill_date,status),
  KEY ix_waybill_trip(trip_id,trip_stop_id),
  CONSTRAINT fk_waybill_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_waybill_trip FOREIGN KEY(trip_id) REFERENCES trips(id),
  CONSTRAINT fk_waybill_stop FOREIGN KEY(trip_stop_id) REFERENCES trip_stops(id),
  CONSTRAINT fk_waybill_invoice FOREIGN KEY(sales_invoice_id) REFERENCES sales_invoices(id),
  CONSTRAINT fk_waybill_sender FOREIGN KEY(sender_party_id) REFERENCES parties(id),
  CONSTRAINT fk_waybill_receiver FOREIGN KEY(receiver_party_id) REFERENCES parties(id),
  CONSTRAINT fk_waybill_creator FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS waybill_lines (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  waybill_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NULL,
  description VARCHAR(500) NOT NULL,
  unit VARCHAR(40) NULL,
  quantity DECIMAL(20,4) NOT NULL DEFAULT 0,
  weight DECIMAL(20,4) NOT NULL DEFAULT 0,
  declared_value DECIMAL(20,2) NOT NULL DEFAULT 0,
  CONSTRAINT fk_wbl_waybill FOREIGN KEY(waybill_id) REFERENCES waybills(id) ON DELETE CASCADE,
  CONSTRAINT fk_wbl_product FOREIGN KEY(product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
