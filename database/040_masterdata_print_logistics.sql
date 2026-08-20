-- TARAZPAD Enterprise 1.8 — rich master data, price lists, printing and logistics documents

CREATE TABLE IF NOT EXISTS product_groups (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  parent_id BIGINT UNSIGNED NULL,
  code VARCHAR(50) NOT NULL,
  title VARCHAR(180) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_pgroup_code(company_id,code),
  KEY ix_pgroup_parent(company_id,parent_id,sort_order),
  CONSTRAINT fk_pgroup_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_pgroup_parent FOREIGN KEY(parent_id) REFERENCES product_groups(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

ALTER TABLE products
  ADD COLUMN group_id BIGINT UNSIGNED NULL,
  ADD COLUMN print_name VARCHAR(250) NULL,
  ADD COLUMN secondary_unit VARCHAR(40) NULL,
  ADD COLUMN secondary_unit_ratio DECIMAL(20,6) NULL,
  ADD COLUMN minimum_sale_price DECIMAL(20,2) NOT NULL DEFAULT 0,
  ADD COLUMN maximum_discount_pct DECIMAL(8,4) NOT NULL DEFAULT 0,
  ADD COLUMN description TEXT NULL,
  ADD COLUMN default_image_url VARCHAR(1000) NULL,
  ADD CONSTRAINT fk_product_group FOREIGN KEY(group_id) REFERENCES product_groups(id);

CREATE TABLE IF NOT EXISTS product_media (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  media_type ENUM('IMAGE','DOCUMENT') NOT NULL DEFAULT 'IMAGE',
  title VARCHAR(180) NULL,
  object_url VARCHAR(1000) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_primary TINYINT(1) NOT NULL DEFAULT 0,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_product_media(product_id,media_type,sort_order),
  CONSTRAINT fk_pm_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_pm_product FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE,
  CONSTRAINT fk_pm_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

ALTER TABLE parties
  ADD COLUMN salutation VARCHAR(30) NULL,
  ADD COLUMN trade_name VARCHAR(250) NULL,
  ADD COLUMN photo_url VARCHAR(1000) NULL;

ALTER TABLE customer_profiles
  ADD COLUMN cash_credit_limit DECIMAL(20,2) NOT NULL DEFAULT 0,
  ADD COLUMN cheque_credit_limit DECIMAL(20,2) NOT NULL DEFAULT 0,
  ADD COLUMN credit_status ENUM('NORMAL','WARNING','BLOCKED') NOT NULL DEFAULT 'NORMAL';

ALTER TABLE bank_accounts
  ADD COLUMN bank_branch_code VARCHAR(50) NULL,
  ADD COLUMN bank_branch_name VARCHAR(120) NULL,
  ADD COLUMN account_holder VARCHAR(180) NULL;

CREATE TABLE IF NOT EXISTS price_lists (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  code VARCHAR(80) NOT NULL,
  title VARCHAR(200) NOT NULL,
  valid_from DATE NOT NULL,
  valid_to DATE NULL,
  currency_code CHAR(3) NOT NULL DEFAULT 'IRR',
  audience ENUM('GENERAL','RETAIL','WHOLESALE','RESTAURANT','DISTRIBUTOR','CUSTOM') NOT NULL DEFAULT 'GENERAL',
  status ENUM('DRAFT','APPROVED','ACTIVE','EXPIRED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  notes TEXT NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  approved_by BIGINT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_price_list(company_id,code),
  KEY ix_price_list_active(company_id,status,valid_from,valid_to),
  CONSTRAINT fk_pl_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_pl_currency FOREIGN KEY(currency_code) REFERENCES currencies(code),
  CONSTRAINT fk_pl_creator FOREIGN KEY(created_by) REFERENCES users(id),
  CONSTRAINT fk_pl_approver FOREIGN KEY(approved_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS price_list_items (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  price_list_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  sale_price DECIMAL(20,2) NOT NULL,
  minimum_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  maximum_discount_pct DECIMAL(8,4) NOT NULL DEFAULT 0,
  notes VARCHAR(500) NULL,
  UNIQUE KEY uq_price_item(price_list_id,product_id),
  CONSTRAINT fk_pli_list FOREIGN KEY(price_list_id) REFERENCES price_lists(id) ON DELETE CASCADE,
  CONSTRAINT fk_pli_product FOREIGN KEY(product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS document_print_templates (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  document_type ENUM('SALES_INVOICE','PURCHASE_INVOICE','PRICE_LIST','SHIPMENT','DELIVERY_RECEIPT','WAREHOUSE_DOCUMENT') NOT NULL,
  code VARCHAR(80) NOT NULL,
  title VARCHAR(180) NOT NULL,
  paper_size ENUM('A4','A5','A6','CUSTOM') NOT NULL DEFAULT 'A4',
  orientation ENUM('PORTRAIT','LANDSCAPE') NOT NULL DEFAULT 'PORTRAIT',
  template_json JSON NOT NULL,
  is_default TINYINT(1) NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_print_template(company_id,document_type,code),
  CONSTRAINT fk_dpt_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_dpt_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS shipment_documents (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  shipment_no VARCHAR(80) NOT NULL,
  shipment_date DATE NOT NULL,
  trip_id BIGINT UNSIGNED NULL,
  sales_invoice_id BIGINT UNSIGNED NULL,
  customer_party_id BIGINT UNSIGNED NULL,
  vehicle_id BIGINT UNSIGNED NULL,
  driver_party_id BIGINT UNSIGNED NULL,
  carrier_name VARCHAR(200) NULL,
  carrier_tracking_no VARCHAR(120) NULL,
  origin_title VARCHAR(250) NULL,
  origin_address TEXT NULL,
  destination_title VARCHAR(250) NULL,
  destination_address TEXT NULL,
  package_count DECIMAL(20,4) NOT NULL DEFAULT 0,
  gross_weight DECIMAL(20,4) NOT NULL DEFAULT 0,
  tare_weight DECIMAL(20,4) NOT NULL DEFAULT 0,
  net_weight DECIMAL(20,4) NOT NULL DEFAULT 0,
  freight_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  declared_value DECIMAL(20,2) NOT NULL DEFAULT 0,
  payment_method VARCHAR(80) NULL,
  barcode_value VARCHAR(160) NULL,
  receiver_name VARCHAR(180) NULL,
  receiver_mobile VARCHAR(30) NULL,
  receiver_note TEXT NULL,
  delivered_at DATETIME NULL,
  status ENUM('DRAFT','READY','DISPATCHED','DELIVERED','RETURNED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_shipment_no(company_id,shipment_no),
  KEY ix_shipment_trip(trip_id,status),
  CONSTRAINT fk_ship_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_ship_trip FOREIGN KEY(trip_id) REFERENCES trips(id),
  CONSTRAINT fk_ship_invoice FOREIGN KEY(sales_invoice_id) REFERENCES sales_invoices(id),
  CONSTRAINT fk_ship_customer FOREIGN KEY(customer_party_id) REFERENCES parties(id),
  CONSTRAINT fk_ship_vehicle FOREIGN KEY(vehicle_id) REFERENCES vehicles(id),
  CONSTRAINT fk_ship_driver FOREIGN KEY(driver_party_id) REFERENCES parties(id),
  CONSTRAINT fk_ship_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS shipment_document_lines (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  shipment_document_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NULL,
  description VARCHAR(500) NOT NULL,
  unit VARCHAR(40) NULL,
  quantity DECIMAL(20,4) NOT NULL DEFAULT 0,
  package_count DECIMAL(20,4) NOT NULL DEFAULT 0,
  gross_weight DECIMAL(20,4) NOT NULL DEFAULT 0,
  net_weight DECIMAL(20,4) NOT NULL DEFAULT 0,
  unit_value DECIMAL(20,2) NOT NULL DEFAULT 0,
  line_value DECIMAL(20,2) NOT NULL DEFAULT 0,
  CONSTRAINT fk_sdl_header FOREIGN KEY(shipment_document_id) REFERENCES shipment_documents(id) ON DELETE CASCADE,
  CONSTRAINT fk_sdl_product FOREIGN KEY(product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
