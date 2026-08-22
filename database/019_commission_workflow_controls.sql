ALTER TABLE commission_results
  ADD COLUMN created_by BIGINT UNSIGNED NULL,
  ADD COLUMN reviewed_at DATETIME NULL,
  ADD COLUMN approved_at DATETIME NULL,
  ADD COLUMN payable_at DATETIME NULL,
  ADD COLUMN payment_reference VARCHAR(120) NULL,
  ADD CONSTRAINT fk_comm_result_creator FOREIGN KEY(created_by) REFERENCES users(id);

CREATE TABLE IF NOT EXISTS commission_status_history (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  commission_result_id BIGINT UNSIGNED NOT NULL,
  old_status VARCHAR(40) NULL,
  new_status VARCHAR(40) NOT NULL,
  note VARCHAR(1000) NULL,
  changed_by BIGINT UNSIGNED NOT NULL,
  changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_csh_result FOREIGN KEY(commission_result_id) REFERENCES commission_results(id) ON DELETE CASCADE,
  CONSTRAINT fk_csh_changed_by FOREIGN KEY(changed_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;