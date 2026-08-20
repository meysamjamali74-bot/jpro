CREATE TABLE IF NOT EXISTS bpm_delegations (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  delegator_user_id BIGINT UNSIGNED NOT NULL,
  delegate_user_id BIGINT UNSIGNED NOT NULL,
  valid_from DATETIME NOT NULL,
  valid_to DATETIME NOT NULL,
  scope_json JSON NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_delegation(company_id,delegator_user_id,valid_from,valid_to,is_active),
  CONSTRAINT fk_bd_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_bd_from FOREIGN KEY(delegator_user_id) REFERENCES users(id),
  CONSTRAINT fk_bd_to FOREIGN KEY(delegate_user_id) REFERENCES users(id),
  CONSTRAINT fk_bd_creator FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS dynamic_form_definitions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  code VARCHAR(80) NOT NULL,
  title VARCHAR(250) NOT NULL,
  version_no INT NOT NULL DEFAULT 1,
  schema_json JSON NOT NULL,
  validation_json JSON NULL,
  bpm_definition_id BIGINT UNSIGNED NULL,
  status ENUM('DRAFT','ACTIVE','RETIRED') NOT NULL DEFAULT 'DRAFT',
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_dynamic_form(company_id,code,version_no),
  CONSTRAINT fk_dfd_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_dfd_bpm FOREIGN KEY(bpm_definition_id) REFERENCES bpm_definitions(id),
  CONSTRAINT fk_dfd_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS dynamic_form_submissions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  form_definition_id BIGINT UNSIGNED NOT NULL,
  submission_no VARCHAR(80) NOT NULL,
  data_json JSON NOT NULL,
  status ENUM('DRAFT','SUBMITTED','IN_WORKFLOW','APPROVED','REJECTED','CLOSED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  bpm_instance_id BIGINT UNSIGNED NULL,
  submitted_by BIGINT UNSIGNED NOT NULL,
  submitted_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_form_submission(company_id,submission_no),
  CONSTRAINT fk_dfs_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_dfs_form FOREIGN KEY(form_definition_id) REFERENCES dynamic_form_definitions(id),
  CONSTRAINT fk_dfs_bpm FOREIGN KEY(bpm_instance_id) REFERENCES bpm_instances(id),
  CONSTRAINT fk_dfs_user FOREIGN KEY(submitted_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS crm_campaigns (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  code VARCHAR(80) NOT NULL,
  title VARCHAR(250) NOT NULL,
  channel ENUM('SMS','EMAIL','WHATSAPP','PHONE','PUSH','MULTI') NOT NULL,
  audience_filter_json JSON NULL,
  content_json JSON NOT NULL,
  start_at DATETIME NULL,
  end_at DATETIME NULL,
  status ENUM('DRAFT','SCHEDULED','RUNNING','PAUSED','COMPLETED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_campaign(company_id,code),
  CONSTRAINT fk_campaign_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_campaign_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS campaign_events (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  campaign_id BIGINT UNSIGNED NOT NULL,
  party_id BIGINT UNSIGNED NOT NULL,
  event_type ENUM('QUEUED','SENT','DELIVERED','OPENED','CLICKED','REPLIED','CONVERTED','FAILED','OPTED_OUT') NOT NULL,
  event_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  source_type VARCHAR(80) NULL,
  source_id BIGINT UNSIGNED NULL,
  value_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
  details_json JSON NULL,
  KEY ix_campaign_event(campaign_id,party_id,event_type,event_at),
  CONSTRAINT fk_ce_campaign FOREIGN KEY(campaign_id) REFERENCES crm_campaigns(id) ON DELETE CASCADE,
  CONSTRAINT fk_ce_party FOREIGN KEY(party_id) REFERENCES parties(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS customer_surveys (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  survey_type ENUM('NPS','CSAT','CUSTOM') NOT NULL,
  title VARCHAR(250) NOT NULL,
  schema_json JSON NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_survey_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_survey_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS customer_survey_responses (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  survey_id BIGINT UNSIGNED NOT NULL,
  party_id BIGINT UNSIGNED NULL,
  score DECIMAL(10,4) NULL,
  response_json JSON NULL,
  responded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  source_type VARCHAR(80) NULL,
  source_id BIGINT UNSIGNED NULL,
  CONSTRAINT fk_csr_survey FOREIGN KEY(survey_id) REFERENCES customer_surveys(id) ON DELETE CASCADE,
  CONSTRAINT fk_csr_party FOREIGN KEY(party_id) REFERENCES parties(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;