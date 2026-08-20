-- Enterprise 1.8 compatibility: enrich the existing treasury bank_accounts table without replacing it.
ALTER TABLE bank_accounts
  ADD COLUMN IF NOT EXISTS account_type VARCHAR(80) NULL AFTER account_title,
  ADD COLUMN IF NOT EXISTS branch_code VARCHAR(30) NULL AFTER account_type,
  ADD COLUMN IF NOT EXISTS branch_name VARCHAR(120) NULL AFTER branch_code,
  ADD COLUMN IF NOT EXISTS account_holder VARCHAR(180) NULL AFTER card_no,
  ADD COLUMN IF NOT EXISTS current_balance DECIMAL(20,2) NOT NULL DEFAULT 0 AFTER opening_balance,
  ADD COLUMN IF NOT EXISTS phone VARCHAR(50) NULL AFTER current_balance,
  ADD COLUMN IF NOT EXISTS fax VARCHAR(50) NULL AFTER phone,
  ADD COLUMN IF NOT EXISTS address TEXT NULL AFTER fax,
  ADD COLUMN IF NOT EXISTS notes TEXT NULL AFTER address;

UPDATE bank_accounts
SET current_balance = opening_balance
WHERE current_balance = 0 AND opening_balance <> 0;
