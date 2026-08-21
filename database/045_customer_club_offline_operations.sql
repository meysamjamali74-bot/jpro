-- TARAZPAD Enterprise 1.8 — Offline/LAN Customer Club Operations
-- Operational ownership, auditable bulk import and follow-up queue for an internal MySQL deployment.

CREATE TABLE IF NOT EXISTS customer_club_assignments (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  party_id BIGINT UNSIGNED NOT NULL,
  owner_user_id BIGINT UNSIGNED NOT NULL,
  lifecycle_status ENUM('NEW','ACTIVE','PAUSED','WON','LOST','DO_NOT_CONTACT') NOT NULL DEFAULT 'NEW',
  priority ENUM('LOW','NORMAL','HIGH','CRITICAL') NOT NULL DEFAULT 'NORMAL',
  source VARCHAR(120) NULL,
  next_action_at DATETIME NULL,
  next_action_title VARCHAR(250) NULL,
  last_contact_at DATETIME NULL,
  last_result VARCHAR(500) NULL,
  tags_json JSON NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  updated_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_cc_assignment(company_id,party_id),
  KEY ix_cc_assignment_queue(company_id,owner_user_id,lifecycle_status,next_action_at,priority),
  CONSTRAINT fk_cc_assignment_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_cc_assignment_party FOREIGN KEY(party_id) REFERENCES parties(id) ON DELETE CASCADE,
  CONSTRAINT fk_cc_assignment_owner FOREIGN KEY(owner_user_id) REFERENCES users(id),
  CONSTRAINT fk_cc_assignment_creator FOREIGN KEY(created_by) REFERENCES users(id),
  CONSTRAINT fk_cc_assignment_updater FOREIGN KEY(updated_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS customer_club_import_batches (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  source_name VARCHAR(250) NULL,
  source_type ENUM('CSV','MANUAL','API') NOT NULL DEFAULT 'CSV',
  status ENUM('PROCESSING','COMPLETED','COMPLETED_WITH_ERRORS','FAILED') NOT NULL DEFAULT 'PROCESSING',
  total_rows INT NOT NULL DEFAULT 0,
  inserted_rows INT NOT NULL DEFAULT 0,
  updated_rows INT NOT NULL DEFAULT 0,
  rejected_rows INT NOT NULL DEFAULT 0,
  default_owner_user_id BIGINT UNSIGNED NULL,
  default_source VARCHAR(120) NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at DATETIME NULL,
  KEY ix_cc_import_company(company_id,created_at,status),
  CONSTRAINT fk_cc_import_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_cc_import_owner FOREIGN KEY(default_owner_user_id) REFERENCES users(id),
  CONSTRAINT fk_cc_import_creator FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS customer_club_import_rows (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  batch_id BIGINT UNSIGNED NOT NULL,
  row_no INT NOT NULL,
  party_id BIGINT UNSIGNED NULL,
  row_status ENUM('INSERTED','UPDATED','REJECTED') NOT NULL,
  identity_key VARCHAR(200) NULL,
  error_message VARCHAR(1000) NULL,
  payload_json JSON NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_cc_import_row(batch_id,row_status,row_no),
  CONSTRAINT fk_cc_import_row_batch FOREIGN KEY(batch_id) REFERENCES customer_club_import_batches(id) ON DELETE CASCADE,
  CONSTRAINT fk_cc_import_row_party FOREIGN KEY(party_id) REFERENCES parties(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Guarantee the operational roles needed by the offline customer-club unit exist on fresh installations.
INSERT INTO roles(code,title,is_system) VALUES
 ('CRM_MANAGER','مدیر ارتباط با مشتریان',1),
 ('CUSTOMER_SERVICE','کارشناس خدمات مشتریان',1)
ON DUPLICATE KEY UPDATE title=VALUES(title),is_system=1;
