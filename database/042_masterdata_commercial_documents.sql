-- TARAZPAD Enterprise 1.8 — master data, commercial documents and print-ready logistics

CREATE TABLE IF NOT EXISTS product_groups (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  parent_id BIGINT UNSIGNED NULL,
  code VARCHAR(50) NOT NULL,
  title VARCHAR(200) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_pgrp_code(company_id,code),
  KEY ix_pgrp_parent(company_id,parent_id,sort_order),
  CONSTRAINT fk_pgrp_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_pgrp_parent FOREIGN KEY(parent_id) REFERENCES product_groups(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS product_group_members (
  product_id BIGINT UNSIGNED NOT NULL,
  group_id BIGINT UNSIGNED NOT NULL,
  is_primary TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY(product_id,group_id),
  CONSTRAINT fk_pgmem_product FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE,
  CONSTRAINT fk_pgmem_group FOREIGN KEY(group_id) REFERENCES product_groups(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS product_media (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  media_type ENUM('IMAGE','DOCUMENT') NOT NULL DEFAULT 'IMAGE',
  media_url VARCHAR(1000) NOT NULL,
  caption VARCHAR(250) NULL,
  is_primary TINYINT(1) NOT NULL DEFAULT 0,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_pmedia_product(product_id,is_primary,sort_order),
  CONSTRAINT fk_pmedia_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_pmedia_product FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS party_groups (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  parent_id BIGINT UNSIGNED NULL,
  code VARCHAR(50) NOT NULL,
  title VARCHAR(200) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_partygrp_code(company_id,code),
  KEY ix_partygrp_parent(company_id,parent_id,sort_order),
  CONSTRAINT fk_partygrp_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_partygrp_parent FOREIGN KEY(parent_id) REFERENCES party_groups(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS party_group_members (
  party_id BIGINT UNSIGNED NOT NULL,
  group_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY(party_id,group_id),
  CONSTRAINT fk_partygmem_party FOREIGN KEY(party_id) REFERENCES parties(id) ON DELETE CASCADE,
  CONSTRAINT fk_partygmem_group FOREIGN KEY(group_id) REFERENCES party_groups(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS party_contacts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  party_id BIGINT UNSIGNED NOT NULL,
  contact_type ENUM('MOBILE','PHONE','FAX','EMAIL','WHATSAPP','OTHER') NOT NULL,
  title VARCHAR(80) NULL,
  contact_value VARCHAR(250) NOT NULL,
  is_primary TINYINT(1) NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  KEY ix_party_contact(party_id,contact_type,is_primary),
  CONSTRAINT fk_pcontact_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_pcontact_party FOREIGN KEY(party_id) REFERENCES parties(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS party_addresses (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  party_id BIGINT UNSIGNED NOT NULL,
  address_type ENUM('MAIN','BILLING','SHIPPING','WAREHOUSE','WORK','OTHER') NOT NULL DEFAULT 'MAIN',
  title VARCHAR(120) NULL,
  province VARCHAR(100) NULL,
  city VARCHAR(100) NULL,
  postal_code VARCHAR(30) NULL,
  address_text TEXT NOT NULL,
  latitude DECIMAL(10,7) NULL,
  longitude DECIMAL(10,7) NULL,
  is_primary TINYINT(1) NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  KEY ix_party_address(party_id,address_type,is_primary),
  CONSTRAINT fk_paddress_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_paddress_party FOREIGN KEY(party_id) REFERENCES parties(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS party_bank_accounts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  party_id BIGINT UNSIGNED NOT NULL,
  bank_name VARCHAR(120) NOT NULL,
  branch_name VARCHAR(120) NULL,
  branch_code VARCHAR(40) NULL,
  account_type VARCHAR(80) NULL,
  account_no VARCHAR(80) NULL,
  card_no VARCHAR(40) NULL,
  iban VARCHAR(40) NULL,
  account_holder VARCHAR(200) NULL,
  is_primary TINYINT(1) NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_party_bank(party_id,is_primary),
  KEY ix_party_iban(company_id,iban),
  CONSTRAINT fk_pbank_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_pbank_party FOREIGN KEY(party_id) REFERENCES parties(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS price_lists (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  code VARCHAR(80) NOT NULL,
  title VARCHAR(200) NOT NULL,
  valid_from DATE NULL,
  valid_to DATE NULL,
  currency_code CHAR(3) NOT NULL DEFAULT 'IRR',
  audience ENUM('PUBLIC','CUSTOMER_GROUP','CUSTOMER','INTERNAL') NOT NULL DEFAULT 'PUBLIC',
  party_group_id BIGINT UNSIGNED NULL,
  party_id BIGINT UNSIGNED NULL,
  status ENUM('DRAFT','ACTIVE','EXPIRED','ARCHIVED') NOT NULL DEFAULT 'DRAFT',
  notes TEXT NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_pricelist_code(company_id,code),
  KEY ix_pricelist_validity(company_id,status,valid_from,valid_to),
  CONSTRAINT fk_pricelist_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_pricelist_currency FOREIGN KEY(currency_code) REFERENCES currencies(code),
  CONSTRAINT fk_pricelist_group FOREIGN KEY(party_group_id) REFERENCES party_groups(id),
  CONSTRAINT fk_pricelist_party FOREIGN KEY(party_id) REFERENCES parties(id),
  CONSTRAINT fk_pricelist_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS price_list_items (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  price_list_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  unit_price DECIMAL(20,2) NOT NULL,
  min_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  max_discount_pct DECIMAL(8,4) NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_pricelist_product(price_list_id,product_id),
  CONSTRAINT fk_pli_header FOREIGN KEY(price_list_id) REFERENCES price_lists(id) ON DELETE CASCADE,
  CONSTRAINT fk_pli_product FOREIGN KEY(product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS logistics_waybills (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  waybill_no VARCHAR(80) NOT NULL,
  issue_date DATE NOT NULL,
  trip_id BIGINT UNSIGNED NULL,
  trip_stop_id BIGINT UNSIGNED NULL,
  sales_invoice_id BIGINT UNSIGNED NULL,
  sender_party_id BIGINT UNSIGNED NULL,
  receiver_party_id BIGINT UNSIGNED NULL,
  carrier_name VARCHAR(200) NULL,
  tracking_no VARCHAR(120) NULL,
  origin_text VARCHAR(500) NULL,
  destination_text VARCHAR(500) NULL,
  package_count DECIMAL(20,4) NOT NULL DEFAULT 0,
  gross_weight DECIMAL(20,4) NOT NULL DEFAULT 0,
  net_weight DECIMAL(20,4) NOT NULL DEFAULT 0,
  freight_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  insurance_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  other_charges DECIMAL(20,2) NOT NULL DEFAULT 0,
  payment_method ENUM('PREPAID','COLLECT','CREDIT','FREE') NOT NULL DEFAULT 'PREPAID',
  description TEXT NULL,
  receiver_name VARCHAR(200) NULL,
  receiver_phone VARCHAR(50) NULL,
  received_at DATETIME NULL,
  status ENUM('DRAFT','ISSUED','IN_TRANSIT','DELIVERED','RETURNED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_waybill_no(company_id,waybill_no),
  KEY ix_waybill_invoice(sales_invoice_id,status),
  KEY ix_waybill_tracking(company_id,tracking_no),
  CONSTRAINT fk_waybill_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_waybill_trip FOREIGN KEY(trip_id) REFERENCES trips(id),
  CONSTRAINT fk_waybill_stop FOREIGN KEY(trip_stop_id) REFERENCES trip_stops(id),
  CONSTRAINT fk_waybill_invoice FOREIGN KEY(sales_invoice_id) REFERENCES sales_invoices(id),
  CONSTRAINT fk_waybill_sender FOREIGN KEY(sender_party_id) REFERENCES parties(id),
  CONSTRAINT fk_waybill_receiver FOREIGN KEY(receiver_party_id) REFERENCES parties(id),
  CONSTRAINT fk_waybill_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS print_profiles (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  document_type ENUM('SALES_INVOICE','PURCHASE_INVOICE','WAYBILL','PRICE_LIST','RECEIPT','PAYMENT') NOT NULL,
  code VARCHAR(80) NOT NULL,
  title VARCHAR(200) NOT NULL,
  paper_size ENUM('A4','A5','THERMAL_80','CUSTOM') NOT NULL DEFAULT 'A4',
  orientation ENUM('PORTRAIT','LANDSCAPE') NOT NULL DEFAULT 'PORTRAIT',
  template_json JSON NULL,
  is_default TINYINT(1) NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_print_profile(company_id,document_type,code),
  CONSTRAINT fk_print_profile_company FOREIGN KEY(company_id) REFERENCES companies(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
