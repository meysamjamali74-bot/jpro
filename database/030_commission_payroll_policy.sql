CREATE TABLE IF NOT EXISTS commission_payroll_settings (
  company_id BIGINT UNSIGNED PRIMARY KEY,
  is_insurable TINYINT(1) NOT NULL DEFAULT 1,
  is_taxable TINYINT(1) NOT NULL DEFAULT 1,
  line_title VARCHAR(180) NOT NULL DEFAULT 'پورسانت فروش و وصول',
  require_approved_result TINYINT(1) NOT NULL DEFAULT 1,
  updated_by BIGINT UNSIGNED NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_cps_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_cps_user FOREIGN KEY(updated_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT IGNORE INTO commission_payroll_settings(company_id,updated_by)
SELECT c.id,MIN(u.id) FROM companies c JOIN users u ON u.company_id=c.id GROUP BY c.id;
