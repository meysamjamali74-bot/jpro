-- Tarazpad Enterprise — maintenance, backup and health operations for fresh Windows/LAN installs.

CREATE TABLE IF NOT EXISTS system_maintenance_settings (
  id TINYINT UNSIGNED PRIMARY KEY,
  backup_directory VARCHAR(1000) NULL,
  full_backup_retention_days INT NOT NULL DEFAULT 30,
  monthly_backup_retention_months INT NOT NULL DEFAULT 12,
  require_restore_test_days INT NOT NULL DEFAULT 30,
  mysqldump_path VARCHAR(1000) NULL,
  mysql_client_path VARCHAR(1000) NULL,
  files_root VARCHAR(1000) NULL,
  updated_by BIGINT UNSIGNED NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_maintenance_settings_user FOREIGN KEY(updated_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO system_maintenance_settings(id,full_backup_retention_days,monthly_backup_retention_months,require_restore_test_days)
VALUES (1,30,12,30)
ON DUPLICATE KEY UPDATE id=VALUES(id);

CREATE TABLE IF NOT EXISTS maintenance_jobs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NULL,
  job_type ENUM('FULL_BACKUP','RESTORE_TEST','INTEGRITY_CHECK') NOT NULL,
  status ENUM('QUEUED','RUNNING','SUCCESS','FAILED','CANCELLED') NOT NULL DEFAULT 'QUEUED',
  priority TINYINT UNSIGNED NOT NULL DEFAULT 5,
  payload_json JSON NULL,
  result_json JSON NULL,
  error_text TEXT NULL,
  requested_by BIGINT UNSIGNED NULL,
  correlation_id VARCHAR(100) NULL,
  requested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  started_at DATETIME NULL,
  completed_at DATETIME NULL,
  KEY ix_maintenance_queue(status,priority,requested_at,id),
  KEY ix_maintenance_company(company_id,requested_at),
  CONSTRAINT fk_maintenance_job_company FOREIGN KEY(company_id) REFERENCES companies(id) ON DELETE CASCADE,
  CONSTRAINT fk_maintenance_job_user FOREIGN KEY(requested_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS backup_runs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NULL,
  backup_type ENUM('FULL','INCREMENTAL','FILES') NOT NULL DEFAULT 'FULL',
  started_at DATETIME NOT NULL,
  completed_at DATETIME NULL,
  status ENUM('RUNNING','SUCCESS','FAILED') NOT NULL DEFAULT 'RUNNING',
  storage_location VARCHAR(1500) NOT NULL,
  size_bytes BIGINT UNSIGNED NULL,
  sha256 CHAR(64) NULL,
  retention_until DATE NULL,
  error_text TEXT NULL,
  created_by BIGINT UNSIGNED NULL,
  KEY ix_backup_status(started_at,status),
  KEY ix_backup_company(company_id,started_at),
  CONSTRAINT fk_backup_run_company FOREIGN KEY(company_id) REFERENCES companies(id) ON DELETE SET NULL,
  CONSTRAINT fk_backup_run_user FOREIGN KEY(created_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS restore_tests (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  backup_run_id BIGINT UNSIGNED NOT NULL,
  tested_at DATETIME NOT NULL,
  status ENUM('SUCCESS','FAILED') NOT NULL,
  integrity_checks_json JSON NULL,
  duration_seconds INT NULL,
  error_text TEXT NULL,
  tested_by BIGINT UNSIGNED NULL,
  KEY ix_restore_test_backup(backup_run_id,tested_at),
  CONSTRAINT fk_restore_test_backup FOREIGN KEY(backup_run_id) REFERENCES backup_runs(id) ON DELETE CASCADE,
  CONSTRAINT fk_restore_test_user FOREIGN KEY(tested_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS system_health_snapshots (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  service_name VARCHAR(120) NOT NULL,
  status ENUM('HEALTHY','DEGRADED','UNHEALTHY') NOT NULL,
  latency_ms INT NULL,
  memory_percent DECIMAL(10,4) NULL,
  db_connections INT NULL,
  details_json JSON NULL,
  captured_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_health_service(service_name,captured_at,status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS background_job_failures (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  job_name VARCHAR(180) NOT NULL,
  correlation_id VARCHAR(100) NULL,
  payload_json JSON NULL,
  error_text TEXT NOT NULL,
  status ENUM('FAILED','RETRYING','RESOLVED') NOT NULL DEFAULT 'FAILED',
  first_failed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_failed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  resolved_at DATETIME NULL,
  KEY ix_background_failure(status,last_failed_at),
  KEY ix_background_correlation(correlation_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
