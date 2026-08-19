CREATE TABLE IF NOT EXISTS account_control_tags (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  account_id BIGINT UNSIGNED NOT NULL,
  control_tag ENUM('SUSPENSE','GRNI','GRIR','CASH','BANK','INTERCOMPANY_DUE_FROM','INTERCOMPANY_DUE_TO','TAX_PAYABLE','PAYROLL_PAYABLE') NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_account_control_tag(company_id,account_id,control_tag),
  KEY ix_account_control_tag(company_id,control_tag,is_active),
  CONSTRAINT fk_act_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_act_account FOREIGN KEY(account_id) REFERENCES accounts(id),
  CONSTRAINT fk_act_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Only seed tags whose source is explicit and authoritative in existing schema.
INSERT IGNORE INTO account_control_tags(company_id,account_id,control_tag,created_by)
SELECT a.company_id,a.id,'INTERCOMPANY_DUE_FROM',MIN(u.id)
FROM accounts a JOIN users u ON u.company_id=a.company_id
WHERE a.code='120900' GROUP BY a.company_id,a.id;

INSERT IGNORE INTO account_control_tags(company_id,account_id,control_tag,created_by)
SELECT a.company_id,a.id,'INTERCOMPANY_DUE_TO',MIN(u.id)
FROM accounts a JOIN users u ON u.company_id=a.company_id
WHERE a.code='220900' GROUP BY a.company_id,a.id;

INSERT IGNORE INTO account_control_tags(company_id,account_id,control_tag,created_by)
SELECT b.company_id,b.gl_account_id,'BANK',MIN(u.id)
FROM bank_accounts b JOIN users u ON u.company_id=b.company_id
WHERE b.gl_account_id IS NOT NULL
GROUP BY b.company_id,b.gl_account_id;

-- GRNI/GRIR/SUSPENSE are deliberately NOT guessed from account codes.
-- Finance management assigns these tags explicitly through the control-tag API.
