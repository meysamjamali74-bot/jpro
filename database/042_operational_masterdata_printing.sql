-- TARAZPAD Enterprise 1.8: detailed master data, price lists, logistics waybills and print profiles

CREATE TABLE IF NOT EXISTS party_groups (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  parent_id BIGINT UNSIGNED NULL,
  code VARCHAR(50) NOT NULL,
  title VARCHAR(200) NOT NULL,
  group_type ENUM('CUSTOMER','SUPPLIER','EMPLOYEE','SALESPERSON','DRIVER','GENERAL') NOT NULL DEFAULT 'GENERAL',
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_party_group(company_id,code),
  KEY ix_party_group_parent(parent_id),
  CONSTRAINT fk_pgrp_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_pgrp_parent FOREIGN KEY(parent_id) REFERENCES party_groups(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS party_group_members (
  party_group_id BIGINT UNSIGNED NOT NULL,
  party_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY(party_group_id,party_id),
  CONSTRAINT fk_pgm_group FOREIGN KEY(party_group_id) REFERENCES party_groups(id) ON DELETE CASCADE,
  CONSTRAINT fk_pgm_party FOREIGN KEY(party_id) REFERENCES parties(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS party_contacts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  party_id BIGINT UNSIGNED NOT NULL,
  contact_type ENUM('MOBILE','PHONE','FAX','EMAIL','WHATSAPP','OTHER') NOT NULL,
  label VARCHAR(80) NULL,
  contact_value VARCHAR(250) NOT NULL,
  is_primary TINYINT(1) NOT NULL DEFAULT 0,
  sort_order INT NOT NULL DEFAULT 0,
  CONSTRAINT fk_pcontact_party FOREIGN KEY(party_id) REFERENCES parties(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS party_addresses (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  party_id BIGINT UNSIGNED NOT NULL,
  address_type ENUM('MAIN','BILLING','DELIVERY','WORK','OTHER') NOT NULL DEFAULT 'MAIN',
  title VARCHAR(120) NULL,
  province VARCHAR(100) NULL,
  city VARCHAR(100) NULL,
  postal_code VARCHAR(20) NULL,
  address_text VARCHAR(1000) NOT NULL,
  latitude DECIMAL(10,7) NULL,
  longitude DECIMAL(10,7) NULL,
  is_primary TINYINT(1) NOT NULL DEFAULT 0,
  CONSTRAINT fk_paddr_party FOREIGN KEY(party_id) REFERENCES parties(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS product_groups (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  parent_id BIGINT UNSIGNED NULL,
  code VARCHAR(50) NOT NULL,
  title VARCHAR(200) NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_product_group(company_id,code),
  CONSTRAINT fk_prgrp_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_prgrp_parent FOREIGN KEY(parent_id) REFERENCES product_groups(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS product_group_members (
  product_group_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY(product_group_id,product_id),
  CONSTRAINT fk_prgm_group FOREIGN KEY(product_group_id) REFERENCES product_groups(id) ON DELETE CASCADE,
  CONSTRAINT fk_prgm_product FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS product_media (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  media_type ENUM('IMAGE','DOCUMENT') NOT NULL DEFAULT 'IMAGE',
  storage_ref VARCHAR(1000) NOT NULL,
  alt_text VARCHAR(250) NULL,
  is_primary TINYINT(1) NOT NULL DEFAULT 0,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_pmedia_product(product_id,is_primary,sort_order),
  CONSTRAINT fk_pmedia_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_pmedia_product FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS price_lists (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  code VARCHAR(80) NOT NULL,
  title VARCHAR(200) NOT NULL,
  valid_from DATE NULL,
  valid_to DATE NULL,
  currency_code CHAR(3) NOT NULL DEFAULT 'IRR',
  audience ENUM('GENERAL','RETAIL','WHOLESALE','RESTAURANT','DISTRIBUTOR','CUSTOM') NOT NULL DEFAULT 'GENERAL',
  status ENUM('DRAFT','ACTIVE','EXPIRED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  notes VARCHAR(1000) NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_price_list(company_id,code),
  KEY ix_price_list_status(company_id,status,valid_from,valid_to),
  CONSTRAINT fk_pl_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_pl_creator FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS price_list_lines (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  price_list_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  unit_price DECIMAL(20,2) NOT NULL,
  min_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  max_discount_pct DECIMAL(8,4) NOT NULL DEFAULT 0,
  is_featured TINYINT(1) NOT NULL DEFAULT 0,
  sort_order INT NOT NULL DEFAULT 0,
  UNIQUE KEY uq_price_list_product(price_list_id,product_id),
  CONSTRAINT fk_pll_list FOREIGN KEY(price_list_id) REFERENCES price_lists(id) ON DELETE CASCADE,
  CONSTRAINT fk_pll_product FOREIGN KEY(product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS logistics_waybills (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  waybill_no VARCHAR(80) NOT NULL,
  trip_id BIGINT UNSIGNED NULL,
  sales_invoice_id BIGINT UNSIGNED NULL,
  sender_party_id BIGINT UNSIGNED NULL,
  receiver_party_id BIGINT UNSIGNED NOT NULL,
  origin_address VARCHAR(1000) NULL,
  destination_address VARCHAR(1000) NOT NULL,
  issue_date DATE NOT NULL,
  dispatch_time DATETIME NULL,
  delivery_time DATETIME NULL,
  total_packages DECIMAL(20,4) NOT NULL DEFAULT 0,
  gross_weight DECIMAL(20,4) NOT NULL DEFAULT 0,
  net_weight DECIMAL(20,4) NOT NULL DEFAULT 0,
  freight_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  insurance_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  other_charges DECIMAL(20,2) NOT NULL DEFAULT 0,
  payment_method ENUM('SENDER','RECEIVER','CREDIT','FREE') NOT NULL DEFAULT 'SENDER',
  status ENUM('DRAFT','ISSUED','DISPATCHED','DELIVERED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  receiver_name VARCHAR(200) NULL,
  receiver_signature_ref VARCHAR(1000) NULL,
  notes VARCHAR(1500) NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_waybill(company_id,waybill_no),
  KEY ix_waybill_date(company_id,issue_date,status),
  CONSTRAINT fk_waybill_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_waybill_trip FOREIGN KEY(trip_id) REFERENCES trips(id),
  CONSTRAINT fk_waybill_invoice FOREIGN KEY(sales_invoice_id) REFERENCES sales_invoices(id),
  CONSTRAINT fk_waybill_sender FOREIGN KEY(sender_party_id) REFERENCES parties(id),
  CONSTRAINT fk_waybill_receiver FOREIGN KEY(receiver_party_id) REFERENCES parties(id),
  CONSTRAINT fk_waybill_creator FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS logistics_waybill_lines (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  waybill_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NULL,
  description VARCHAR(500) NOT NULL,
  unit VARCHAR(40) NULL,
  package_count DECIMAL(20,4) NOT NULL DEFAULT 0,
  quantity DECIMAL(20,4) NOT NULL DEFAULT 0,
  gross_weight DECIMAL(20,4) NOT NULL DEFAULT 0,
  net_weight DECIMAL(20,4) NOT NULL DEFAULT 0,
  declared_value DECIMAL(20,2) NOT NULL DEFAULT 0,
  CONSTRAINT fk_wbl_waybill FOREIGN KEY(waybill_id) REFERENCES logistics_waybills(id) ON DELETE CASCADE,
  CONSTRAINT fk_wbl_product FOREIGN KEY(product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS document_print_profiles (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  document_type ENUM('SALES_INVOICE','PURCHASE_INVOICE','WAYBILL','PRICE_LIST','PAYMENT_REQUEST','RECEIPT','WAREHOUSE_RECEIPT','WAREHOUSE_ISSUE') NOT NULL,
  profile_code VARCHAR(80) NOT NULL,
  title VARCHAR(200) NOT NULL,
  paper_size ENUM('A4','A5','A6','80MM','CUSTOM') NOT NULL DEFAULT 'A4',
  orientation ENUM('PORTRAIT','LANDSCAPE') NOT NULL DEFAULT 'PORTRAIT',
  template_json JSON NOT NULL,
  is_default TINYINT(1) NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_print_profile(company_id,document_type,profile_code),
  CONSTRAINT fk_dpp_company FOREIGN KEY(company_id) REFERENCES companies(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS document_print_logs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  document_type VARCHAR(50) NOT NULL,
  document_id BIGINT UNSIGNED NOT NULL,
  print_profile_id BIGINT UNSIGNED NULL,
  printed_by BIGINT UNSIGNED NOT NULL,
  printed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  print_hash CHAR(64) NULL,
  KEY ix_print_log_doc(company_id,document_type,document_id,printed_at),
  CONSTRAINT fk_dpl_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_dpl_profile FOREIGN KEY(print_profile_id) REFERENCES document_print_profiles(id),
  CONSTRAINT fk_dpl_user FOREIGN KEY(printed_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
