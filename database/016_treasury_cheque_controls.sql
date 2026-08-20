ALTER TABLE treasury_account_settings
  ADD COLUMN cheque_receivable_account_id BIGINT UNSIGNED NULL,
  ADD COLUMN cheque_payable_account_id BIGINT UNSIGNED NULL;

ALTER TABLE receipts
  ADD COLUMN cheque_id BIGINT UNSIGNED NULL,
  ADD CONSTRAINT fk_receipt_cheque FOREIGN KEY(cheque_id) REFERENCES cheques(id);

ALTER TABLE payments
  ADD COLUMN cheque_id BIGINT UNSIGNED NULL,
  ADD CONSTRAINT fk_payment_cheque FOREIGN KEY(cheque_id) REFERENCES cheques(id);

INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'110300','اسناد دریافتنی',3,'DEBIT','ASSET',1 FROM companies;
INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'210400','اسناد پرداختنی',3,'CREDIT','LIABILITY',1 FROM companies;

UPDATE treasury_account_settings tas
JOIN accounts ar ON ar.company_id=tas.company_id AND ar.code='110300'
JOIN accounts ap ON ap.company_id=tas.company_id AND ap.code='210400'
SET tas.cheque_receivable_account_id=ar.id,
    tas.cheque_payable_account_id=ap.id
WHERE tas.cheque_receivable_account_id IS NULL OR tas.cheque_payable_account_id IS NULL;

ALTER TABLE treasury_account_settings
  MODIFY cheque_receivable_account_id BIGINT UNSIGNED NOT NULL,
  MODIFY cheque_payable_account_id BIGINT UNSIGNED NOT NULL,
  ADD CONSTRAINT fk_tas_chq_rec FOREIGN KEY(cheque_receivable_account_id) REFERENCES accounts(id),
  ADD CONSTRAINT fk_tas_chq_pay FOREIGN KEY(cheque_payable_account_id) REFERENCES accounts(id);