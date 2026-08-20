CREATE TABLE IF NOT EXISTS bank_import_batches (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  bank_account_id BIGINT UNSIGNED NOT NULL,
  file_name VARCHAR(255) NULL,
  file_hash VARCHAR(128) NULL,
  imported_rows INT NOT NULL DEFAULT 0,
  duplicate_rows INT NOT NULL DEFAULT 0,
  invalid_rows INT NOT NULL DEFAULT 0,
  imported_by BIGINT UNSIGNED NOT NULL,
  imported_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_bank_import_file(company_id,bank_account_id,file_hash),
  CONSTRAINT fk_bib_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_bib_bank FOREIGN KEY(bank_account_id) REFERENCES bank_accounts(id),
  CONSTRAINT fk_bib_user FOREIGN KEY(imported_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

ALTER TABLE bank_statement_lines
  ADD COLUMN import_batch_id BIGINT UNSIGNED NULL,
  ADD COLUMN row_hash VARCHAR(128) NULL,
  ADD UNIQUE KEY uq_bank_statement_row(company_id,bank_account_id,row_hash),
  ADD CONSTRAINT fk_bsl_batch FOREIGN KEY(import_batch_id) REFERENCES bank_import_batches(id) ON DELETE SET NULL;