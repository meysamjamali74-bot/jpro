-- Enterprise 1.8: rich master data, price lists, printing and logistics documents
ALTER TABLE products
  ADD COLUMN IF NOT EXISTS short_name VARCHAR(160) NULL,
  ADD COLUMN IF NOT EXISTS model VARCHAR(100) NULL,
  ADD COLUMN IF NOT EXISTS country_of_origin VARCHAR(100) NULL,
  ADD COLUMN IF NOT EXISTS purchase_price DECIMAL(20,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS image_url VARCHAR(1000) NULL,
  ADD COLUMN IF NOT EXISTS description TEXT NULL,
  ADD COLUMN IF NOT EXISTS technical_spec JSON NULL,
  ADD COLUMN IF NOT EXISTS sales_taxable TINYINT(1) NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS purchase_taxable TINYINT(1) NOT NULL DEFAULT 1;

CREATE TABLE IF NOT EXISTS product_groups (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, company_id BIGINT UNSIGNED NOT NULL,
 parent_id BIGINT UNSIGNED NULL, code VARCHAR(50) NOT NULL, title VARCHAR(180) NOT NULL,
 level_no TINYINT UNSIGNED NOT NULL DEFAULT 1, sort_order INT NOT NULL DEFAULT 0, is_active TINYINT(1) NOT NULL DEFAULT 1,
 UNIQUE KEY uq_pgroup_code(company_id,code), KEY ix_pgroup_parent(parent_id),
 CONSTRAINT fk_pgroup_company FOREIGN KEY(company_id) REFERENCES companies(id),
 CONSTRAINT fk_pgroup_parent FOREIGN KEY(parent_id) REFERENCES product_groups(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS product_group_members (
 product_id BIGINT UNSIGNED NOT NULL, group_id BIGINT UNSIGNED NOT NULL, is_primary TINYINT(1) NOT NULL DEFAULT 0,
 PRIMARY KEY(product_id,group_id), CONSTRAINT fk_pgm_product FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE,
 CONSTRAINT fk_pgm_group FOREIGN KEY(group_id) REFERENCES product_groups(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS product_units (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, product_id BIGINT UNSIGNED NOT NULL, unit_name VARCHAR(50) NOT NULL,
 conversion_factor DECIMAL(20,6) NOT NULL DEFAULT 1, barcode VARCHAR(120) NULL, is_base TINYINT(1) NOT NULL DEFAULT 0,
 UNIQUE KEY uq_product_unit(product_id,unit_name), KEY ix_product_unit_barcode(barcode),
 CONSTRAINT fk_product_unit_product FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS service_groups (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, company_id BIGINT UNSIGNED NOT NULL, parent_id BIGINT UNSIGNED NULL,
 code VARCHAR(50) NOT NULL, title VARCHAR(180) NOT NULL, is_active TINYINT(1) NOT NULL DEFAULT 1,
 UNIQUE KEY uq_service_group(company_id,code), CONSTRAINT fk_service_group_company FOREIGN KEY(company_id) REFERENCES companies(id),
 CONSTRAINT fk_service_group_parent FOREIGN KEY(parent_id) REFERENCES service_groups(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS services (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, company_id BIGINT UNSIGNED NOT NULL, group_id BIGINT UNSIGNED NULL,
 code VARCHAR(50) NOT NULL, name VARCHAR(250) NOT NULL, unit VARCHAR(40) NOT NULL DEFAULT 'عدد', sale_price DECIMAL(20,2) NOT NULL DEFAULT 0,
 vat_rate DECIMAL(8,4) NOT NULL DEFAULT 0, commission_rate DECIMAL(8,4) NOT NULL DEFAULT 0, description TEXT NULL,
 is_active TINYINT(1) NOT NULL DEFAULT 1, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE KEY uq_service_code(company_id,code), CONSTRAINT fk_service_company FOREIGN KEY(company_id) REFERENCES companies(id),
 CONSTRAINT fk_service_group FOREIGN KEY(group_id) REFERENCES service_groups(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS party_groups (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, company_id BIGINT UNSIGNED NOT NULL, parent_id BIGINT UNSIGNED NULL,
 code VARCHAR(50) NOT NULL, title VARCHAR(180) NOT NULL, is_active TINYINT(1) NOT NULL DEFAULT 1,
 UNIQUE KEY uq_party_group(company_id,code), CONSTRAINT fk_party_group_company FOREIGN KEY(company_id) REFERENCES companies(id),
 CONSTRAINT fk_party_group_parent FOREIGN KEY(parent_id) REFERENCES party_groups(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS party_group_members (
 party_id BIGINT UNSIGNED NOT NULL, group_id BIGINT UNSIGNED NOT NULL, PRIMARY KEY(party_id,group_id),
 CONSTRAINT fk_party_gm_party FOREIGN KEY(party_id) REFERENCES parties(id) ON DELETE CASCADE,
 CONSTRAINT fk_party_gm_group FOREIGN KEY(group_id) REFERENCES party_groups(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS party_details (
 party_id BIGINT UNSIGNED PRIMARY KEY, prefix VARCHAR(30) NULL, first_name VARCHAR(120) NULL, last_name VARCHAR(160) NULL,
 company_name VARCHAR(250) NULL, registration_no VARCHAR(60) NULL, postal_code VARCHAR(30) NULL, website VARCHAR(250) NULL,
 opening_balance DECIMAL(20,2) NOT NULL DEFAULT 0, opening_balance_nature ENUM('DEBIT','CREDIT','ZERO') NOT NULL DEFAULT 'ZERO',
 cheque_credit_limit DECIMAL(20,2) NOT NULL DEFAULT 0, receivable_credit_limit DECIMAL(20,2) NOT NULL DEFAULT 0,
 notes TEXT NULL, photo_url VARCHAR(1000) NULL,
 CONSTRAINT fk_party_details_party FOREIGN KEY(party_id) REFERENCES parties(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS party_contacts (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, party_id BIGINT UNSIGNED NOT NULL,
 contact_type ENUM('MOBILE','PHONE','FAX','EMAIL','WHATSAPP','OTHER') NOT NULL, title VARCHAR(80) NULL, value VARCHAR(250) NOT NULL,
 is_primary TINYINT(1) NOT NULL DEFAULT 0, sort_order INT NOT NULL DEFAULT 0,
 KEY ix_party_contacts(party_id,contact_type), CONSTRAINT fk_party_contact_party FOREIGN KEY(party_id) REFERENCES parties(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS party_addresses (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, party_id BIGINT UNSIGNED NOT NULL, address_type ENUM('MAIN','BILLING','DELIVERY','OTHER') NOT NULL DEFAULT 'MAIN',
 province VARCHAR(100) NULL, city VARCHAR(100) NULL, address_text TEXT NOT NULL, postal_code VARCHAR(30) NULL,
 latitude DECIMAL(10,7) NULL, longitude DECIMAL(10,7) NULL, is_primary TINYINT(1) NOT NULL DEFAULT 0,
 KEY ix_party_address(party_id,address_type), CONSTRAINT fk_party_address_party FOREIGN KEY(party_id) REFERENCES parties(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS bank_accounts (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, company_id BIGINT UNSIGNED NOT NULL, account_code VARCHAR(50) NOT NULL,
 bank_name VARCHAR(120) NOT NULL, account_type VARCHAR(80) NULL, branch_code VARCHAR(30) NULL, branch_name VARCHAR(120) NULL,
 account_no VARCHAR(80) NOT NULL, iban VARCHAR(40) NULL, card_no VARCHAR(40) NULL, account_holder VARCHAR(180) NULL,
 opening_balance DECIMAL(20,2) NOT NULL DEFAULT 0, current_balance DECIMAL(20,2) NOT NULL DEFAULT 0,
 phone VARCHAR(50) NULL, fax VARCHAR(50) NULL, address TEXT NULL, notes TEXT NULL, is_active TINYINT(1) NOT NULL DEFAULT 1,
 UNIQUE KEY uq_bank_account(company_id,account_code), KEY ix_bank_iban(company_id,iban),
 CONSTRAINT fk_bank_account_company FOREIGN KEY(company_id) REFERENCES companies(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS price_lists (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, company_id BIGINT UNSIGNED NOT NULL, code VARCHAR(80) NOT NULL,
 title VARCHAR(200) NOT NULL, valid_from DATE NULL, valid_to DATE NULL, currency_code CHAR(3) NOT NULL DEFAULT 'IRR',
 audience VARCHAR(120) NULL, notes TEXT NULL, status ENUM('DRAFT','ACTIVE','EXPIRED','ARCHIVED') NOT NULL DEFAULT 'DRAFT',
 created_by BIGINT UNSIGNED NOT NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE KEY uq_price_list(company_id,code), CONSTRAINT fk_price_list_company FOREIGN KEY(company_id) REFERENCES companies(id),
 CONSTRAINT fk_price_list_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS price_list_items (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, price_list_id BIGINT UNSIGNED NOT NULL, product_id BIGINT UNSIGNED NOT NULL,
 unit_name VARCHAR(50) NULL, price DECIMAL(20,2) NOT NULL, old_price DECIMAL(20,2) NULL, min_qty DECIMAL(20,4) NULL,
 item_note VARCHAR(250) NULL, sort_order INT NOT NULL DEFAULT 0, UNIQUE KEY uq_price_list_item(price_list_id,product_id,unit_name),
 CONSTRAINT fk_price_item_list FOREIGN KEY(price_list_id) REFERENCES price_lists(id) ON DELETE CASCADE,
 CONSTRAINT fk_price_item_product FOREIGN KEY(product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS print_templates (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, company_id BIGINT UNSIGNED NOT NULL, document_type VARCHAR(60) NOT NULL,
 code VARCHAR(80) NOT NULL, title VARCHAR(180) NOT NULL, page_size VARCHAR(20) NOT NULL DEFAULT 'A4', orientation ENUM('PORTRAIT','LANDSCAPE') NOT NULL DEFAULT 'PORTRAIT',
 template_json JSON NOT NULL, is_default TINYINT(1) NOT NULL DEFAULT 0, is_active TINYINT(1) NOT NULL DEFAULT 1,
 UNIQUE KEY uq_print_template(company_id,code), KEY ix_print_doc(company_id,document_type),
 CONSTRAINT fk_print_template_company FOREIGN KEY(company_id) REFERENCES companies(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS waybills (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, company_id BIGINT UNSIGNED NOT NULL, waybill_no VARCHAR(80) NOT NULL,
 trip_id BIGINT UNSIGNED NULL, sales_invoice_id BIGINT UNSIGNED NULL, issue_date DATE NOT NULL, carrier_name VARCHAR(200) NULL,
 tracking_no VARCHAR(120) NULL, barcode_value VARCHAR(160) NULL, origin_city VARCHAR(100) NULL, origin_address TEXT NULL,
 destination_city VARCHAR(100) NULL, destination_address TEXT NULL, sender_name VARCHAR(200) NULL, sender_phone VARCHAR(50) NULL,
 receiver_name VARCHAR(200) NOT NULL, receiver_phone VARCHAR(50) NULL, receiver_national_id VARCHAR(30) NULL,
 goods_description VARCHAR(500) NULL, package_count DECIMAL(20,4) NOT NULL DEFAULT 0, gross_weight DECIMAL(20,4) NOT NULL DEFAULT 0,
 declared_value DECIMAL(20,2) NOT NULL DEFAULT 0, freight_amount DECIMAL(20,2) NOT NULL DEFAULT 0, insurance_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
 packing_amount DECIMAL(20,2) NOT NULL DEFAULT 0, loading_amount DECIMAL(20,2) NOT NULL DEFAULT 0, cod_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
 payment_method VARCHAR(80) NULL, delivery_note TEXT NULL, status ENUM('DRAFT','ISSUED','IN_TRANSIT','DELIVERED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
 created_by BIGINT UNSIGNED NOT NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE KEY uq_waybill(company_id,waybill_no), KEY ix_waybill_tracking(company_id,tracking_no),
 CONSTRAINT fk_waybill_company FOREIGN KEY(company_id) REFERENCES companies(id),
 CONSTRAINT fk_waybill_trip FOREIGN KEY(trip_id) REFERENCES trips(id), CONSTRAINT fk_waybill_invoice FOREIGN KEY(sales_invoice_id) REFERENCES sales_invoices(id),
 CONSTRAINT fk_waybill_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;