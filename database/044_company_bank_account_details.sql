-- TARAZPAD Enterprise 1.8 — detailed company bank account master.
-- SECURITY: CVV2/CVC is intentionally never stored in Tarazpad.
-- Existing balances, GL mappings and reconciliation links remain untouched.

ALTER TABLE bank_accounts
  ADD COLUMN branch_name VARCHAR(120) NULL AFTER bank_name,
  ADD COLUMN branch_code VARCHAR(40) NULL AFTER branch_name,
  ADD COLUMN account_type VARCHAR(80) NULL AFTER branch_code,
  ADD COLUMN account_holder VARCHAR(200) NULL AFTER account_title,
  ADD COLUMN card_expiry VARCHAR(7) NULL AFTER card_no,
  ADD COLUMN bank_phone VARCHAR(50) NULL AFTER card_expiry,
  ADD COLUMN bank_fax VARCHAR(50) NULL AFTER bank_phone,
  ADD COLUMN bank_address VARCHAR(500) NULL AFTER bank_fax,
  ADD COLUMN description VARCHAR(1000) NULL AFTER bank_address,
  ADD COLUMN show_on_sales_invoice TINYINT(1) NOT NULL DEFAULT 0 AFTER description,
  ADD COLUMN show_on_receipt TINYINT(1) NOT NULL DEFAULT 0 AFTER show_on_sales_invoice,
  ADD COLUMN is_default TINYINT(1) NOT NULL DEFAULT 0 AFTER show_on_receipt;

UPDATE bank_accounts
SET iban=UPPER(REPLACE(REPLACE(iban,' ',''),'-',''))
WHERE iban IS NOT NULL;

CREATE INDEX ix_bank_default_print
  ON bank_accounts(company_id,is_default,show_on_sales_invoice,is_active);
