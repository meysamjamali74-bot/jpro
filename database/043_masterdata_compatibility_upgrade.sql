-- Enterprise 1.8 compatibility upgrade for master data tables that already exist since 007.
-- Preserve existing data and extend the old schema instead of replacing it.

ALTER TABLE party_addresses
  ADD COLUMN latitude DECIMAL(10,7) NULL,
  ADD COLUMN longitude DECIMAL(10,7) NULL;

ALTER TABLE party_bank_accounts
  ADD COLUMN branch_name VARCHAR(120) NULL AFTER bank_name,
  ADD COLUMN branch_code VARCHAR(40) NULL AFTER branch_name,
  ADD COLUMN account_type VARCHAR(80) NULL AFTER branch_code;

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
