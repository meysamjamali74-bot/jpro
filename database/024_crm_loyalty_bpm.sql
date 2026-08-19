-- TARAZPAD Enterprise 1.4 — CRM, Loyalty, BPM, Office Automation, DMS

CREATE TABLE IF NOT EXISTS crm_leads (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  lead_no VARCHAR(80) NOT NULL,
  title VARCHAR(250) NOT NULL,
  person_name VARCHAR(200) NULL,
  company_name VARCHAR(200) NULL,
  mobile VARCHAR(40) NULL,
  phone VARCHAR(40) NULL,
  email VARCHAR(200) NULL,
  source VARCHAR(100) NULL,
  campaign VARCHAR(120) NULL,
  industry VARCHAR(120) NULL,
  region VARCHAR(120) NULL,
  owner_user_id BIGINT UNSIGNED NOT NULL,
  estimated_value DECIMAL(20,2) NOT NULL DEFAULT 0,
  score DECIMAL(10,4) NOT NULL DEFAULT 0,
  status ENUM('NEW','CONTACTED','QUALIFIED','DISQUALIFIED','CONVERTED','CLOSED') NOT NULL DEFAULT 'NEW',
  next_action_at DATETIME NULL,
  next_action_title VARCHAR(250) NULL,
  converted_party_id BIGINT UNSIGNED NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_crm_lead(company_id,lead_no),
  KEY ix_crm_lead_owner(company_id,owner_user_id,status,next_action_at),
  CONSTRAINT fk_lead_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_lead_owner FOREIGN KEY(owner_user_id) REFERENCES users(id),
  CONSTRAINT fk_lead_party FOREIGN KEY(converted_party_id) REFERENCES parties(id),
  CONSTRAINT fk_lead_creator FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS crm_opportunities (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  opportunity_no VARCHAR(80) NOT NULL,
  party_id BIGINT UNSIGNED NOT NULL,
  lead_id BIGINT UNSIGNED NULL,
  title VARCHAR(250) NOT NULL,
  owner_user_id BIGINT UNSIGNED NOT NULL,
  stage ENUM('QUALIFICATION','NEEDS_ANALYSIS','PROPOSAL','NEGOTIATION','DECISION','WON','LOST') NOT NULL DEFAULT 'QUALIFICATION',
  estimated_value DECIMAL(20,2) NOT NULL DEFAULT 0,
  probability DECIMAL(8,4) NOT NULL DEFAULT 0,
  expected_close_date DATE NULL,
  next_action_at DATETIME NULL,
  next_action_title VARCHAR(250) NULL,
  lost_reason VARCHAR(500) NULL,
  source VARCHAR(120) NULL,
  sales_order_id BIGINT UNSIGNED NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_crm_opp(company_id,opportunity_no),
  KEY ix_crm_opp_pipeline(company_id,owner_user_id,stage,expected_close_date),
  CONSTRAINT fk_opp_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_opp_party FOREIGN KEY(party_id) REFERENCES parties(id),
  CONSTRAINT fk_opp_lead FOREIGN KEY(lead_id) REFERENCES crm_leads(id),
  CONSTRAINT fk_opp_owner FOREIGN KEY(owner_user_id) REFERENCES users(id),
  CONSTRAINT fk_opp_order FOREIGN KEY(sales_order_id) REFERENCES sales_orders(id),
  CONSTRAINT fk_opp_creator FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS crm_activities (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  party_id BIGINT UNSIGNED NULL,
  lead_id BIGINT UNSIGNED NULL,
  opportunity_id BIGINT UNSIGNED NULL,
  activity_type ENUM('CALL','MEETING','VISIT','EMAIL','MESSAGE','FOLLOW_UP','NOTE','TASK') NOT NULL,
  subject VARCHAR(250) NOT NULL,
  description TEXT NULL,
  owner_user_id BIGINT UNSIGNED NOT NULL,
  scheduled_at DATETIME NULL,
  completed_at DATETIME NULL,
  result VARCHAR(500) NULL,
  next_action_at DATETIME NULL,
  next_action_title VARCHAR(250) NULL,
  status ENUM('OPEN','IN_PROGRESS','COMPLETED','CANCELLED','OVERDUE') NOT NULL DEFAULT 'OPEN',
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_crm_activity_owner(company_id,owner_user_id,status,scheduled_at),
  KEY ix_crm_activity_party(company_id,party_id,created_at),
  CONSTRAINT fk_ca_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_ca_party FOREIGN KEY(party_id) REFERENCES parties(id),
  CONSTRAINT fk_ca_lead FOREIGN KEY(lead_id) REFERENCES crm_leads(id),
  CONSTRAINT fk_ca_opp FOREIGN KEY(opportunity_id) REFERENCES crm_opportunities(id),
  CONSTRAINT fk_ca_owner FOREIGN KEY(owner_user_id) REFERENCES users(id),
  CONSTRAINT fk_ca_creator FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS crm_tickets (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  ticket_no VARCHAR(80) NOT NULL,
  party_id BIGINT UNSIGNED NOT NULL,
  ticket_type ENUM('COMPLAINT','REQUEST','RETURN','QUESTION','SERVICE','OTHER') NOT NULL,
  subject VARCHAR(250) NOT NULL,
  description TEXT NULL,
  priority ENUM('LOW','NORMAL','HIGH','CRITICAL') NOT NULL DEFAULT 'NORMAL',
  status ENUM('NEW','ASSIGNED','IN_PROGRESS','WAITING_CUSTOMER','WAITING_INTERNAL','RESOLVED','CLOSED','CANCELLED') NOT NULL DEFAULT 'NEW',
  owner_user_id BIGINT UNSIGNED NULL,
  sla_due_at DATETIME NULL,
  first_response_at DATETIME NULL,
  resolved_at DATETIME NULL,
  closed_at DATETIME NULL,
  resolution TEXT NULL,
  source VARCHAR(80) NULL,
  related_sales_invoice_id BIGINT UNSIGNED NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_crm_ticket(company_id,ticket_no),
  KEY ix_crm_ticket_sla(company_id,status,sla_due_at,priority),
  CONSTRAINT fk_ctk_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_ctk_party FOREIGN KEY(party_id) REFERENCES parties(id),
  CONSTRAINT fk_ctk_owner FOREIGN KEY(owner_user_id) REFERENCES users(id),
  CONSTRAINT fk_ctk_invoice FOREIGN KEY(related_sales_invoice_id) REFERENCES sales_invoices(id),
  CONSTRAINT fk_ctk_creator FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS enterprise_cases (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  case_no VARCHAR(80) NOT NULL,
  case_type ENUM('CUSTOMER_COMPLAINT','INVENTORY_VARIANCE','FINANCIAL_EXCEPTION','LOGISTICS_INCIDENT','HR_INCIDENT','SUPPLIER_CLAIM','OTHER') NOT NULL,
  title VARCHAR(250) NOT NULL,
  description TEXT NULL,
  priority ENUM('LOW','NORMAL','HIGH','CRITICAL') NOT NULL DEFAULT 'NORMAL',
  status ENUM('OPEN','INVESTIGATING','ACTION_REQUIRED','WAITING','RESOLVED','CLOSED','CANCELLED') NOT NULL DEFAULT 'OPEN',
  owner_user_id BIGINT UNSIGNED NOT NULL,
  party_id BIGINT UNSIGNED NULL,
  source_type VARCHAR(80) NULL,
  source_id BIGINT UNSIGNED NULL,
  root_cause TEXT NULL,
  resolution TEXT NULL,
  sla_due_at DATETIME NULL,
  closed_at DATETIME NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_case(company_id,case_no),
  KEY ix_case_owner(company_id,owner_user_id,status,sla_due_at),
  CONSTRAINT fk_case_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_case_owner FOREIGN KEY(owner_user_id) REFERENCES users(id),
  CONSTRAINT fk_case_party FOREIGN KEY(party_id) REFERENCES parties(id),
  CONSTRAINT fk_case_creator FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS case_actions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  case_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(250) NOT NULL,
  responsible_user_id BIGINT UNSIGNED NOT NULL,
  due_at DATETIME NULL,
  status ENUM('OPEN','IN_PROGRESS','DONE','CANCELLED') NOT NULL DEFAULT 'OPEN',
  evidence_ref VARCHAR(500) NULL,
  note TEXT NULL,
  completed_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_case_action_case FOREIGN KEY(case_id) REFERENCES enterprise_cases(id) ON DELETE CASCADE,
  CONSTRAINT fk_case_action_user FOREIGN KEY(responsible_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS customer_health_snapshots (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  party_id BIGINT UNSIGNED NOT NULL,
  snapshot_date DATE NOT NULL,
  sales_score DECIMAL(10,4) NOT NULL DEFAULT 0,
  profit_score DECIMAL(10,4) NOT NULL DEFAULT 0,
  collection_score DECIMAL(10,4) NOT NULL DEFAULT 0,
  delay_score DECIMAL(10,4) NOT NULL DEFAULT 0,
  complaint_score DECIMAL(10,4) NOT NULL DEFAULT 0,
  activity_score DECIMAL(10,4) NOT NULL DEFAULT 0,
  repeat_score DECIMAL(10,4) NOT NULL DEFAULT 0,
  health_score DECIMAL(10,4) NOT NULL,
  health_state ENUM('EXCELLENT','HEALTHY','AT_RISK','CRITICAL') NOT NULL,
  details_json JSON NULL,
  UNIQUE KEY uq_health(company_id,party_id,snapshot_date),
  CONSTRAINT fk_health_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_health_party FOREIGN KEY(party_id) REFERENCES parties(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS contact_consents (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  party_id BIGINT UNSIGNED NOT NULL,
  channel ENUM('SMS','EMAIL','WHATSAPP','PHONE','PUSH') NOT NULL,
  consent_status ENUM('OPT_IN','OPT_OUT','UNKNOWN') NOT NULL DEFAULT 'UNKNOWN',
  consent_date DATETIME NULL,
  source VARCHAR(120) NULL,
  frequency_cap_per_week INT NULL,
  updated_by BIGINT UNSIGNED NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_consent(company_id,party_id,channel),
  CONSTRAINT fk_consent_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_consent_party FOREIGN KEY(party_id) REFERENCES parties(id),
  CONSTRAINT fk_consent_user FOREIGN KEY(updated_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS loyalty_tiers (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  code VARCHAR(50) NOT NULL,
  title VARCHAR(120) NOT NULL,
  min_points DECIMAL(20,2) NOT NULL DEFAULT 0,
  min_annual_spend DECIMAL(20,2) NOT NULL DEFAULT 0,
  benefits_json JSON NULL,
  priority INT NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_loyalty_tier(company_id,code),
  CONSTRAINT fk_lt_company FOREIGN KEY(company_id) REFERENCES companies(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS loyalty_accounts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  party_id BIGINT UNSIGNED NOT NULL,
  member_no VARCHAR(80) NOT NULL,
  tier_id BIGINT UNSIGNED NULL,
  points_balance DECIMAL(20,2) NOT NULL DEFAULT 0,
  wallet_balance DECIMAL(20,2) NOT NULL DEFAULT 0,
  status ENUM('ACTIVE','SUSPENDED','CLOSED') NOT NULL DEFAULT 'ACTIVE',
  joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_loyalty_party(company_id,party_id),
  UNIQUE KEY uq_loyalty_member(company_id,member_no),
  CONSTRAINT fk_la_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_la_party FOREIGN KEY(party_id) REFERENCES parties(id),
  CONSTRAINT fk_la_tier FOREIGN KEY(tier_id) REFERENCES loyalty_tiers(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS loyalty_ledger (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  loyalty_account_id BIGINT UNSIGNED NOT NULL,
  transaction_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  transaction_type ENUM('EARN_POINTS','REDEEM_POINTS','EXPIRE_POINTS','MANUAL_POINTS','WALLET_CHARGE','WALLET_USE','CASHBACK','REFUND','ADJUSTMENT','REVERSAL') NOT NULL,
  points_delta DECIMAL(20,2) NOT NULL DEFAULT 0,
  wallet_delta DECIMAL(20,2) NOT NULL DEFAULT 0,
  source_type VARCHAR(80) NULL,
  source_id BIGINT UNSIGNED NULL,
  idempotency_key VARCHAR(120) NULL,
  expires_at DATETIME NULL,
  status ENUM('POSTED','REVERSED','EXPIRED') NOT NULL DEFAULT 'POSTED',
  related_ledger_id BIGINT UNSIGNED NULL,
  description VARCHAR(500) NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_loyalty_idempotency(company_id,idempotency_key),
  KEY ix_loyalty_ledger_account(loyalty_account_id,transaction_date,status),
  CONSTRAINT fk_ll_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_ll_account FOREIGN KEY(loyalty_account_id) REFERENCES loyalty_accounts(id),
  CONSTRAINT fk_ll_related FOREIGN KEY(related_ledger_id) REFERENCES loyalty_ledger(id),
  CONSTRAINT fk_ll_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS loyalty_rules (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(200) NOT NULL,
  event_type ENUM('SALE','COLLECTION','REFERRAL','BIRTHDAY','SURVEY','REPEAT_PURCHASE','CAMPAIGN') NOT NULL,
  points_per_amount DECIMAL(20,6) NOT NULL DEFAULT 0,
  fixed_points DECIMAL(20,2) NOT NULL DEFAULT 0,
  cashback_percent DECIMAL(10,4) NOT NULL DEFAULT 0,
  filter_json JSON NULL,
  effective_from DATE NOT NULL,
  effective_to DATE NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  CONSTRAINT fk_lr_company FOREIGN KEY(company_id) REFERENCES companies(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS loyalty_rewards (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  code VARCHAR(80) NOT NULL,
  title VARCHAR(200) NOT NULL,
  reward_type ENUM('DISCOUNT','WALLET','PRODUCT','SERVICE','COUPON') NOT NULL,
  point_cost DECIMAL(20,2) NOT NULL DEFAULT 0,
  wallet_cost DECIMAL(20,2) NOT NULL DEFAULT 0,
  stock_qty DECIMAL(20,4) NULL,
  valid_from DATE NULL,
  valid_to DATE NULL,
  restrictions_json JSON NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_reward(company_id,code),
  CONSTRAINT fk_reward_company FOREIGN KEY(company_id) REFERENCES companies(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS loyalty_redemptions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  loyalty_account_id BIGINT UNSIGNED NOT NULL,
  reward_id BIGINT UNSIGNED NOT NULL,
  redemption_no VARCHAR(80) NOT NULL,
  points_used DECIMAL(20,2) NOT NULL DEFAULT 0,
  wallet_used DECIMAL(20,2) NOT NULL DEFAULT 0,
  quantity DECIMAL(20,4) NOT NULL DEFAULT 1,
  status ENUM('REQUESTED','APPROVED','FULFILLED','CANCELLED','REVERSED') NOT NULL DEFAULT 'REQUESTED',
  idempotency_key VARCHAR(120) NULL,
  requested_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fulfilled_at DATETIME NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  UNIQUE KEY uq_redemption_no(company_id,redemption_no),
  UNIQUE KEY uq_redemption_idem(company_id,idempotency_key),
  CONSTRAINT fk_red_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_red_account FOREIGN KEY(loyalty_account_id) REFERENCES loyalty_accounts(id),
  CONSTRAINT fk_red_reward FOREIGN KEY(reward_id) REFERENCES loyalty_rewards(id),
  CONSTRAINT fk_red_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS loyalty_referrals (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  referrer_account_id BIGINT UNSIGNED NOT NULL,
  referral_code VARCHAR(80) NOT NULL,
  referred_party_id BIGINT UNSIGNED NULL,
  status ENUM('INVITED','REGISTERED','QUALIFIED','REWARDED','REJECTED') NOT NULL DEFAULT 'INVITED',
  qualified_at DATETIME NULL,
  rewarded_at DATETIME NULL,
  fraud_flag TINYINT(1) NOT NULL DEFAULT 0,
  fraud_reason VARCHAR(500) NULL,
  UNIQUE KEY uq_referral_code(company_id,referral_code),
  CONSTRAINT fk_ref_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_ref_account FOREIGN KEY(referrer_account_id) REFERENCES loyalty_accounts(id),
  CONSTRAINT fk_ref_party FOREIGN KEY(referred_party_id) REFERENCES parties(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS bpm_definitions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  code VARCHAR(80) NOT NULL,
  title VARCHAR(250) NOT NULL,
  entity_type VARCHAR(80) NOT NULL,
  version_no INT NOT NULL DEFAULT 1,
  definition_json JSON NOT NULL,
  status ENUM('DRAFT','ACTIVE','RETIRED') NOT NULL DEFAULT 'DRAFT',
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_bpm_def(company_id,code,version_no),
  CONSTRAINT fk_bpm_def_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_bpm_def_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS bpm_instances (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  definition_id BIGINT UNSIGNED NOT NULL,
  entity_type VARCHAR(80) NOT NULL,
  entity_id BIGINT UNSIGNED NOT NULL,
  status ENUM('RUNNING','WAITING','COMPLETED','REJECTED','CANCELLED','FAILED') NOT NULL DEFAULT 'RUNNING',
  current_node VARCHAR(120) NULL,
  variables_json JSON NULL,
  started_by BIGINT UNSIGNED NOT NULL,
  started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at DATETIME NULL,
  KEY ix_bpm_instance_entity(company_id,entity_type,entity_id,status),
  CONSTRAINT fk_bpm_inst_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_bpm_inst_def FOREIGN KEY(definition_id) REFERENCES bpm_definitions(id),
  CONSTRAINT fk_bpm_inst_user FOREIGN KEY(started_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS bpm_work_items (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  bpm_instance_id BIGINT UNSIGNED NOT NULL,
  node_code VARCHAR(120) NOT NULL,
  title VARCHAR(250) NOT NULL,
  assigned_user_id BIGINT UNSIGNED NULL,
  assigned_role_code VARCHAR(80) NULL,
  status ENUM('OPEN','CLAIMED','IN_PROGRESS','WAITING_INFO','RETURNED','APPROVED','REJECTED','COMPLETED','CANCELLED') NOT NULL DEFAULT 'OPEN',
  due_at DATETIME NULL,
  escalation_level INT NOT NULL DEFAULT 0,
  claimed_at DATETIME NULL,
  completed_at DATETIME NULL,
  completed_by BIGINT UNSIGNED NULL,
  decision VARCHAR(80) NULL,
  note TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_bwi_assignee(assigned_user_id,status,due_at),
  KEY ix_bwi_role(assigned_role_code,status,due_at),
  CONSTRAINT fk_bwi_inst FOREIGN KEY(bpm_instance_id) REFERENCES bpm_instances(id) ON DELETE CASCADE,
  CONSTRAINT fk_bwi_assign FOREIGN KEY(assigned_user_id) REFERENCES users(id),
  CONSTRAINT fk_bwi_complete FOREIGN KEY(completed_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS automation_rules (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(250) NOT NULL,
  trigger_type VARCHAR(100) NOT NULL,
  trigger_config_json JSON NULL,
  condition_json JSON NULL,
  action_json JSON NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  last_run_at DATETIME NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_auto_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_auto_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS office_letters (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  letter_no VARCHAR(100) NOT NULL,
  letter_type ENUM('INTERNAL','INCOMING','OUTGOING') NOT NULL,
  letter_date DATE NOT NULL,
  subject VARCHAR(300) NOT NULL,
  sender_text VARCHAR(250) NULL,
  receiver_text VARCHAR(250) NULL,
  confidentiality ENUM('NORMAL','CONFIDENTIAL','VERY_CONFIDENTIAL') NOT NULL DEFAULT 'NORMAL',
  urgency ENUM('NORMAL','URGENT','IMMEDIATE') NOT NULL DEFAULT 'NORMAL',
  body_text LONGTEXT NULL,
  status ENUM('DRAFT','REGISTERED','REFERRED','CLOSED','ARCHIVED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  owner_user_id BIGINT UNSIGNED NOT NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_letter(company_id,letter_no),
  CONSTRAINT fk_letter_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_letter_owner FOREIGN KEY(owner_user_id) REFERENCES users(id),
  CONSTRAINT fk_letter_creator FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS letter_referrals (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  letter_id BIGINT UNSIGNED NOT NULL,
  from_user_id BIGINT UNSIGNED NOT NULL,
  to_user_id BIGINT UNSIGNED NOT NULL,
  referral_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  instruction TEXT NULL,
  due_at DATETIME NULL,
  status ENUM('UNREAD','READ','IN_PROGRESS','DONE','RETURNED') NOT NULL DEFAULT 'UNREAD',
  read_at DATETIME NULL,
  done_at DATETIME NULL,
  CONSTRAINT fk_lr_letter FOREIGN KEY(letter_id) REFERENCES office_letters(id) ON DELETE CASCADE,
  CONSTRAINT fk_lr_from FOREIGN KEY(from_user_id) REFERENCES users(id),
  CONSTRAINT fk_lr_to FOREIGN KEY(to_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS meetings (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  meeting_no VARCHAR(80) NOT NULL,
  title VARCHAR(250) NOT NULL,
  meeting_at DATETIME NOT NULL,
  location VARCHAR(250) NULL,
  organizer_user_id BIGINT UNSIGNED NOT NULL,
  agenda TEXT NULL,
  minutes_text LONGTEXT NULL,
  status ENUM('PLANNED','HELD','CLOSED','CANCELLED') NOT NULL DEFAULT 'PLANNED',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_meeting(company_id,meeting_no),
  CONSTRAINT fk_meet_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_meet_org FOREIGN KEY(organizer_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS meeting_actions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  meeting_id BIGINT UNSIGNED NOT NULL,
  decision_text TEXT NOT NULL,
  responsible_user_id BIGINT UNSIGNED NOT NULL,
  due_at DATETIME NULL,
  status ENUM('OPEN','IN_PROGRESS','DONE','OVERDUE','CANCELLED') NOT NULL DEFAULT 'OPEN',
  evidence_ref VARCHAR(500) NULL,
  completed_at DATETIME NULL,
  CONSTRAINT fk_ma_meeting FOREIGN KEY(meeting_id) REFERENCES meetings(id) ON DELETE CASCADE,
  CONSTRAINT fk_ma_user FOREIGN KEY(responsible_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS dms_documents (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  document_no VARCHAR(100) NOT NULL,
  title VARCHAR(300) NOT NULL,
  document_class VARCHAR(120) NULL,
  confidentiality ENUM('NORMAL','CONFIDENTIAL','VERY_CONFIDENTIAL') NOT NULL DEFAULT 'NORMAL',
  owner_user_id BIGINT UNSIGNED NOT NULL,
  entity_type VARCHAR(80) NULL,
  entity_id BIGINT UNSIGNED NULL,
  retention_until DATE NULL,
  expires_at DATE NULL,
  status ENUM('ACTIVE','ARCHIVED','EXPIRED','VOID') NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_dms_doc(company_id,document_no),
  KEY ix_dms_entity(company_id,entity_type,entity_id),
  CONSTRAINT fk_dms_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_dms_owner FOREIGN KEY(owner_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS dms_versions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  document_id BIGINT UNSIGNED NOT NULL,
  version_no INT NOT NULL,
  storage_ref VARCHAR(1000) NOT NULL,
  file_name VARCHAR(255) NOT NULL,
  mime_type VARCHAR(120) NULL,
  file_size BIGINT UNSIGNED NULL,
  sha256 VARCHAR(64) NOT NULL,
  change_note VARCHAR(500) NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_dms_version(document_id,version_no),
  CONSTRAINT fk_dmsv_doc FOREIGN KEY(document_id) REFERENCES dms_documents(id) ON DELETE CASCADE,
  CONSTRAINT fk_dmsv_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'210700','تعهدات باشگاه مشتریان',3,'CREDIT','LIABILITY',1 FROM companies;
INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'620100','هزینه وفاداری و جوایز مشتریان',3,'DEBIT','EXPENSE',1 FROM companies;
