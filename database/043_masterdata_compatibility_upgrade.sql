-- Enterprise 1.8 compatibility upgrade for master data tables that already exist since 007.
-- Preserve legacy contacts/addresses/banks and extend them to the unified commercial master schema.

ALTER TABLE party_contacts
  MODIFY COLUMN full_name VARCHAR(180) NULL,
  ADD COLUMN company_id BIGINT UNSIGNED NULL AFTER id,
  ADD COLUMN contact_type ENUM('MOBILE','PHONE','FAX','EMAIL','WHATSAPP','OTHER') NULL AFTER party_id,
  ADD COLUMN title VARCHAR(80) NULL AFTER contact_type,
  ADD COLUMN contact_value VARCHAR(250) NULL AFTER title,
  ADD COLUMN is_active TINYINT(1) NOT NULL DEFAULT 1 AFTER is_primary;

UPDATE party_contacts pc
JOIN parties p ON p.id=pc.party_id
SET pc.company_id=p.company_id,
    pc.contact_type=COALESCE(pc.contact_type,CASE
      WHEN NULLIF(pc.mobile,'') IS NOT NULL THEN 'MOBILE'
      WHEN NULLIF(pc.phone,'') IS NOT NULL THEN 'PHONE'
      WHEN NULLIF(pc.email,'') IS NOT NULL THEN 'EMAIL'
      ELSE 'OTHER' END),
    pc.title=COALESCE(pc.title,NULLIF(pc.job_title,''),NULLIF(pc.full_name,''),'تماس'),
    pc.contact_value=COALESCE(NULLIF(pc.contact_value,''),NULLIF(pc.mobile,''),NULLIF(pc.phone,''),NULLIF(pc.email,''),'');

ALTER TABLE party_contacts
  MODIFY COLUMN company_id BIGINT UNSIGNED NOT NULL,
  MODIFY COLUMN contact_type ENUM('MOBILE','PHONE','FAX','EMAIL','WHATSAPP','OTHER') NOT NULL,
  MODIFY COLUMN contact_value VARCHAR(250) NOT NULL,
  ADD KEY ix_pcontact_company(company_id,party_id,contact_type,is_primary),
  ADD CONSTRAINT fk_pcontact_company_v8 FOREIGN KEY(company_id) REFERENCES companies(id);

ALTER TABLE party_addresses
  ADD COLUMN company_id BIGINT UNSIGNED NULL AFTER id,
  MODIFY COLUMN address_type ENUM('MAIN','BILLING','SHIPPING','WAREHOUSE','DELIVERY','WORK','OTHER') NOT NULL DEFAULT 'MAIN',
  MODIFY COLUMN address TEXT NULL,
  ADD COLUMN address_text TEXT NULL AFTER address,
  ADD COLUMN latitude DECIMAL(10,7) NULL AFTER phone,
  ADD COLUMN longitude DECIMAL(10,7) NULL AFTER latitude,
  ADD COLUMN is_primary TINYINT(1) NOT NULL DEFAULT 0 AFTER is_default,
  ADD COLUMN is_active TINYINT(1) NOT NULL DEFAULT 1 AFTER is_primary;

UPDATE party_addresses pa
JOIN parties p ON p.id=pa.party_id
SET pa.company_id=p.company_id,
    pa.address_text=COALESCE(pa.address_text,pa.address,''),
    pa.is_primary=IF(pa.is_default=1,1,pa.is_primary);

ALTER TABLE party_addresses
  MODIFY COLUMN company_id BIGINT UNSIGNED NOT NULL,
  MODIFY COLUMN address_text TEXT NOT NULL,
  ADD KEY ix_paddress_company(company_id,party_id,address_type,is_primary),
  ADD CONSTRAINT fk_paddress_company_v8 FOREIGN KEY(company_id) REFERENCES companies(id);

ALTER TABLE party_bank_accounts
  ADD COLUMN company_id BIGINT UNSIGNED NULL AFTER id,
  ADD COLUMN branch_name VARCHAR(120) NULL AFTER bank_name,
  ADD COLUMN branch_code VARCHAR(40) NULL AFTER branch_name,
  ADD COLUMN account_type VARCHAR(80) NULL AFTER branch_code,
  ADD COLUMN is_primary TINYINT(1) NOT NULL DEFAULT 0 AFTER verification_status,
  ADD COLUMN is_active TINYINT(1) NOT NULL DEFAULT 1 AFTER is_primary,
  ADD COLUMN created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER verified_at;

UPDATE party_bank_accounts pb
JOIN parties p ON p.id=pb.party_id
SET pb.company_id=p.company_id,
    pb.is_primary=IF(pb.is_default=1,1,pb.is_primary);

ALTER TABLE party_bank_accounts
  MODIFY COLUMN company_id BIGINT UNSIGNED NOT NULL,
  ADD KEY ix_pbank_company(company_id,party_id,is_primary),
  ADD CONSTRAINT fk_pbank_company_v8 FOREIGN KEY(company_id) REFERENCES companies(id);

-- Services use the same products master so they remain usable in invoices, taxation and accounting.
CREATE TABLE IF NOT EXISTS service_profiles (
  product_id BIGINT UNSIGNED PRIMARY KEY,
  commission_pct DECIMAL(8,4) NOT NULL DEFAULT 0,
  revenue_account_id BIGINT UNSIGNED NULL,
  estimated_duration_minutes INT NULL,
  service_notes TEXT NULL,
  CONSTRAINT fk_service_profile_product FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE,
  CONSTRAINT fk_service_profile_revenue_account FOREIGN KEY(revenue_account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
