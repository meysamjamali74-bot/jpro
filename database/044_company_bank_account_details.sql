-- Enterprise 1.8 — detailed company bank account master used by treasury and printed documents.
ALTER TABLE bank_accounts
  ADD COLUMN branch_name VARCHAR(120) NULL AFTER bank_name,
  ADD COLUMN branch_code VARCHAR(40) NULL AFTER branch_name,
  ADD COLUMN account_type VARCHAR(80) NULL AFTER branch_code,
  ADD COLUMN account_holder VARCHAR(200) NULL AFTER account_title,
  ADD COLUMN card_expiry VARCHAR(10) NULL AFTER card_no,
  ADD COLUMN cvv2 VARCHAR(10) NULL AFTER card_expiry,
  ADD COLUMN bank_phone VARCHAR(50) NULL AFTER cvv2,
  ADD COLUMN bank_fax VARCHAR(50) NULL AFTER bank_phone,
  ADD COLUMN bank_address VARCHAR(500) NULL AFTER bank_fax,
  ADD COLUMN notes VARCHAR(1000) NULL AFTER bank_address,
  ADD COLUMN show_on_invoice TINYINT(1) NOT NULL DEFAULT 1 AFTER notes,
  ADD COLUMN show_on_receipt TINYINT(1) NOT NULL DEFAULT 1 AFTER show_on_invoice;
