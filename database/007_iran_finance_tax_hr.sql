ALTER TABLE companies ADD COLUMN national_id VARCHAR(30) NULL, ADD COLUMN economic_code VARCHAR(40) NULL, ADD COLUMN registration_no VARCHAR(40) NULL, ADD COLUMN postal_code VARCHAR(20) NULL, ADD COLUMN province VARCHAR(100) NULL, ADD COLUMN city VARCHAR(100) NULL, ADD COLUMN address TEXT NULL;

ALTER TABLE parties ADD COLUMN registration_no VARCHAR(40) NULL, ADD COLUMN postal_code VARCHAR(20) NULL, ADD COLUMN province VARCHAR(100) NULL, ADD COLUMN city VARCHAR(100) NULL, ADD COLUMN tax_branch_code VARCHAR(50) NULL, ADD COLUMN tax_file_no VARCHAR(80) NULL, ADD COLUMN contact_person VARCHAR(150) NULL, ADD COLUMN website VARCHAR(200) NULL, ADD COLUMN notes TEXT NULL;

CREATE TABLE IF NOT EXISTS party_addresses (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,party_id BIGINT UNSIGNED NOT NULL,address_type ENUM('MAIN','BILLING','SHIPPING','WORK','OTHER') NOT NULL DEFAULT 'MAIN',title VARCHAR(120) NULL,province VARCHAR(100) NULL,city VARCHAR(100) NULL,address TEXT NOT NULL,postal_code VARCHAR(20) NULL,phone VARCHAR(50) NULL,is_default TINYINT(1) NOT NULL DEFAULT 0,
 KEY ix_party_address(party_id,address_type),CONSTRAINT fk_party_address_party FOREIGN KEY(party_id) REFERENCES parties(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS party_contacts (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,party_id BIGINT UNSIGNED NOT NULL,full_name VARCHAR(180) NOT NULL,job_title VARCHAR(120) NULL,mobile VARCHAR(30) NULL,phone VARCHAR(50) NULL,email VARCHAR(190) NULL,is_primary TINYINT(1) NOT NULL DEFAULT 0,notes VARCHAR(500) NULL,
 KEY ix_party_contact(party_id,is_primary),CONSTRAINT fk_party_contact_party FOREIGN KEY(party_id) REFERENCES parties(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS party_bank_accounts (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,party_id BIGINT UNSIGNED NOT NULL,bank_name VARCHAR(120) NOT NULL,account_no VARCHAR(80) NULL,iban VARCHAR(40) NULL,card_no VARCHAR(30) NULL,account_holder VARCHAR(180) NULL,is_default TINYINT(1) NOT NULL DEFAULT 0,verification_status ENUM('UNVERIFIED','PENDING','VERIFIED','REJECTED') NOT NULL DEFAULT 'UNVERIFIED',verified_by BIGINT UNSIGNED NULL,verified_at DATETIME NULL,
 KEY ix_party_bank(party_id,is_default),KEY ix_party_bank_iban(iban),CONSTRAINT fk_party_bank_party FOREIGN KEY(party_id) REFERENCES parties(id) ON DELETE CASCADE,CONSTRAINT fk_party_bank_verifier FOREIGN KEY(verified_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

ALTER TABLE products ADD COLUMN goods_service_id VARCHAR(20) NULL, ADD COLUMN unit_code VARCHAR(20) NULL, ADD COLUMN vat_status ENUM('STANDARD','EXEMPT','ZERO','SPECIAL') NOT NULL DEFAULT 'STANDARD', ADD COLUMN default_vat_rate DECIMAL(8,4) NULL, ADD COLUMN purchase_price DECIMAL(20,2) NOT NULL DEFAULT 0, ADD COLUMN product_type ENUM('GOODS','SERVICE') NOT NULL DEFAULT 'GOODS';

CREATE TABLE IF NOT EXISTS company_tax_profiles (
 company_id BIGINT UNSIGNED PRIMARY KEY,taxpayer_memory_id VARCHAR(20) NULL,economic_code VARCHAR(40) NULL,national_id VARCHAR(30) NULL,postal_code VARCHAR(20) NULL,address TEXT NULL,tax_terminal_id VARCHAR(80) NULL,default_invoice_type ENUM('TYPE_1','TYPE_2','TYPE_3','NON_ELECTRONIC') NOT NULL DEFAULT 'TYPE_1',default_invoice_pattern VARCHAR(50) NOT NULL DEFAULT 'SALE',taxpayer_system_enabled TINYINT(1) NOT NULL DEFAULT 0,updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 CONSTRAINT fk_tax_profile_company FOREIGN KEY(company_id) REFERENCES companies(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS tax_rates (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,company_id BIGINT UNSIGNED NULL,tax_code VARCHAR(50) NOT NULL,title VARCHAR(180) NOT NULL,rate DECIMAL(8,4) NOT NULL,effective_from DATE NOT NULL,effective_to DATE NULL,tax_kind ENUM('VAT','DUTY','WITHHOLDING','OTHER') NOT NULL DEFAULT 'VAT',applies_to VARCHAR(100) NULL,is_active TINYINT(1) NOT NULL DEFAULT 1,legal_reference VARCHAR(500) NULL,
 UNIQUE KEY uq_tax_rate(company_id,tax_code,effective_from),KEY ix_tax_effective(tax_kind,effective_from,effective_to)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

ALTER TABLE sales_invoices ADD COLUMN invoice_classification ENUM('OFFICIAL','NON_OFFICIAL') NOT NULL DEFAULT 'NON_OFFICIAL', ADD COLUMN tax_invoice_type ENUM('TYPE_1','TYPE_2','TYPE_3','NON_ELECTRONIC') NULL, ADD COLUMN tax_invoice_pattern VARCHAR(50) NULL, ADD COLUMN settlement_type ENUM('CASH','CREDIT','MIXED') NOT NULL DEFAULT 'CASH', ADD COLUMN cash_amount DECIMAL(20,2) NOT NULL DEFAULT 0, ADD COLUMN credit_amount DECIMAL(20,2) NOT NULL DEFAULT 0, ADD COLUMN tax_unique_no VARCHAR(40) NULL, ADD COLUMN tax_memory_id VARCHAR(20) NULL, ADD COLUMN tax_reference_no VARCHAR(40) NULL, ADD COLUMN tax_status ENUM('NOT_REQUIRED','DRAFT','READY','QUEUED','SENT','ACCEPTED','REJECTED','CANCELLED') NOT NULL DEFAULT 'NOT_REQUIRED', ADD COLUMN tax_sent_at DATETIME NULL, ADD COLUMN tax_response_json JSON NULL, ADD COLUMN invoice_subject ENUM('ORIGINAL','AMENDMENT','CANCELLATION','RETURN') NOT NULL DEFAULT 'ORIGINAL', ADD COLUMN notes TEXT NULL;

ALTER TABLE sales_invoice_lines ADD COLUMN description VARCHAR(500) NULL, ADD COLUMN goods_service_id VARCHAR(20) NULL, ADD COLUMN unit_code VARCHAR(20) NULL, ADD COLUMN vat_status ENUM('STANDARD','EXEMPT','ZERO','SPECIAL') NOT NULL DEFAULT 'STANDARD', ADD COLUMN vat_rate DECIMAL(8,4) NOT NULL DEFAULT 0, ADD COLUMN amount_before_discount DECIMAL(20,2) NOT NULL DEFAULT 0, ADD COLUMN amount_after_discount DECIMAL(20,2) NOT NULL DEFAULT 0, ADD COLUMN other_duties_amount DECIMAL(20,2) NOT NULL DEFAULT 0, ADD COLUMN other_duties_description VARCHAR(250) NULL;

CREATE TABLE IF NOT EXISTS invoice_tax_events (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,company_id BIGINT UNSIGNED NOT NULL,sales_invoice_id BIGINT UNSIGNED NOT NULL,event_type ENUM('VALIDATE','QUEUE','SEND','ACCEPT','REJECT','CANCEL','RETURN') NOT NULL,status VARCHAR(50) NOT NULL,request_json JSON NULL,response_json JSON NULL,error_message TEXT NULL,created_by BIGINT UNSIGNED NULL,created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 KEY ix_invoice_tax_event(sales_invoice_id,created_at),CONSTRAINT fk_ite_company FOREIGN KEY(company_id) REFERENCES companies(id),CONSTRAINT fk_ite_invoice FOREIGN KEY(sales_invoice_id) REFERENCES sales_invoices(id),CONSTRAINT fk_ite_user FOREIGN KEY(created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS accounting_rule_lines (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,company_id BIGINT UNSIGNED NOT NULL,event_code VARCHAR(80) NOT NULL,line_role ENUM('DEBIT','CREDIT') NOT NULL,amount_source VARCHAR(80) NOT NULL,account_id BIGINT UNSIGNED NOT NULL,party_source VARCHAR(80) NULL,priority INT NOT NULL DEFAULT 10,is_active TINYINT(1) NOT NULL DEFAULT 1,
 UNIQUE KEY uq_acc_rule(company_id,event_code,line_role,amount_source,account_id),CONSTRAINT fk_acc_rule_company FOREIGN KEY(company_id) REFERENCES companies(id),CONSTRAINT fk_acc_rule_account FOREIGN KEY(account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS departments (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,company_id BIGINT UNSIGNED NOT NULL,parent_id BIGINT UNSIGNED NULL,code VARCHAR(50) NOT NULL,title VARCHAR(180) NOT NULL,is_active TINYINT(1) NOT NULL DEFAULT 1,UNIQUE KEY uq_department(company_id,code),CONSTRAINT fk_department_company FOREIGN KEY(company_id) REFERENCES companies(id),CONSTRAINT fk_department_parent FOREIGN KEY(parent_id) REFERENCES departments(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS positions (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,company_id BIGINT UNSIGNED NOT NULL,department_id BIGINT UNSIGNED NULL,code VARCHAR(50) NOT NULL,title VARCHAR(180) NOT NULL,grade VARCHAR(50) NULL,is_active TINYINT(1) NOT NULL DEFAULT 1,UNIQUE KEY uq_position(company_id,code),CONSTRAINT fk_position_company FOREIGN KEY(company_id) REFERENCES companies(id),CONSTRAINT fk_position_department FOREIGN KEY(department_id) REFERENCES departments(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS employee_profiles (
 party_id BIGINT UNSIGNED PRIMARY KEY,personnel_no VARCHAR(50) NOT NULL,national_no VARCHAR(20) NULL,father_name VARCHAR(120) NULL,birth_date DATE NULL,birth_place VARCHAR(100) NULL,gender ENUM('MALE','FEMALE','OTHER') NULL,marital_status ENUM('SINGLE','MARRIED','OTHER') NULL,children_count INT NOT NULL DEFAULT 0,insurance_no VARCHAR(50) NULL,tax_identifier VARCHAR(50) NULL,hire_date DATE NULL,termination_date DATE NULL,department_id BIGINT UNSIGNED NULL,position_id BIGINT UNSIGNED NULL,employment_status ENUM('ACTIVE','ON_LEAVE','SUSPENDED','TERMINATED') NOT NULL DEFAULT 'ACTIVE',education_level VARCHAR(100) NULL,field_of_study VARCHAR(150) NULL,emergency_contact VARCHAR(180) NULL,emergency_phone VARCHAR(30) NULL,
 UNIQUE KEY uq_employee_personnel(personnel_no),CONSTRAINT fk_employee_party FOREIGN KEY(party_id) REFERENCES parties(id) ON DELETE CASCADE,CONSTRAINT fk_employee_department FOREIGN KEY(department_id) REFERENCES departments(id),CONSTRAINT fk_employee_position FOREIGN KEY(position_id) REFERENCES positions(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS employment_contracts (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,company_id BIGINT UNSIGNED NOT NULL,employee_party_id BIGINT UNSIGNED NOT NULL,contract_no VARCHAR(80) NOT NULL,contract_type ENUM('PERMANENT','FIXED_TERM','PROBATION','PART_TIME','HOURLY','OTHER') NOT NULL,start_date DATE NOT NULL,end_date DATE NULL,work_location VARCHAR(200) NULL,working_hours_monthly DECIMAL(10,2) NULL,base_salary_monthly DECIMAL(20,2) NOT NULL DEFAULT 0,daily_wage DECIMAL(20,2) NOT NULL DEFAULT 0,housing_allowance DECIMAL(20,2) NOT NULL DEFAULT 0,food_allowance DECIMAL(20,2) NOT NULL DEFAULT 0,seniority_allowance DECIMAL(20,2) NOT NULL DEFAULT 0,fixed_benefits DECIMAL(20,2) NOT NULL DEFAULT 0,insurance_included TINYINT(1) NOT NULL DEFAULT 1,tax_included TINYINT(1) NOT NULL DEFAULT 1,bank_account_id BIGINT UNSIGNED NULL,status ENUM('DRAFT','ACTIVE','EXPIRED','TERMINATED') NOT NULL DEFAULT 'DRAFT',description TEXT NULL,created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE KEY uq_employment_contract(company_id,contract_no),KEY ix_contract_employee(employee_party_id,start_date,end_date),CONSTRAINT fk_contract_company FOREIGN KEY(company_id) REFERENCES companies(id),CONSTRAINT fk_contract_employee FOREIGN KEY(employee_party_id) REFERENCES parties(id),CONSTRAINT fk_contract_bank FOREIGN KEY(bank_account_id) REFERENCES party_bank_accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS contract_wage_components (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,employment_contract_id BIGINT UNSIGNED NOT NULL,component_code VARCHAR(50) NOT NULL,title VARCHAR(180) NOT NULL,component_type ENUM('EARNING','DEDUCTION') NOT NULL,calculation_type ENUM('FIXED','PERCENT','DAILY','HOURLY','FORMULA') NOT NULL DEFAULT 'FIXED',amount DECIMAL(20,2) NOT NULL DEFAULT 0,rate DECIMAL(10,4) NULL,formula_text VARCHAR(500) NULL,is_insurable TINYINT(1) NOT NULL DEFAULT 0,is_taxable TINYINT(1) NOT NULL DEFAULT 0,is_active TINYINT(1) NOT NULL DEFAULT 1,UNIQUE KEY uq_contract_component(employment_contract_id,component_code),CONSTRAINT fk_cwc_contract FOREIGN KEY(employment_contract_id) REFERENCES employment_contracts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS payroll_legal_parameters (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,company_id BIGINT UNSIGNED NULL,title VARCHAR(200) NOT NULL,effective_from DATE NOT NULL,effective_to DATE NULL,parameters_json JSON NOT NULL,legal_reference VARCHAR(500) NULL,is_active TINYINT(1) NOT NULL DEFAULT 1,KEY ix_payroll_param(effective_from,effective_to,is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO tax_rates(company_id,tax_code,title,rate,effective_from,effective_to,tax_kind,applies_to,is_active,legal_reference)
SELECT NULL,'VAT_GENERAL_1405','نرخ عمومی مالیات بر ارزش افزوده سال ۱۴۰۵',10.0000,'2026-03-21','2027-03-20','VAT','کالا و خدمات موضوع ماده ۷ با رعایت معافیت‌ها و نرخ‌های خاص',1,'قانون مالیات بر ارزش افزوده ماده ۷ و حکم بودجه سال ۱۴۰۵؛ نرخ عمومی ۱۰ درصد'
WHERE NOT EXISTS (SELECT 1 FROM tax_rates WHERE company_id IS NULL AND tax_code='VAT_GENERAL_1405' AND effective_from='2026-03-21');

INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'210300','مالیات و عوارض ارزش افزوده پرداختنی',3,'CREDIT','LIABILITY',1 FROM companies;

INSERT IGNORE INTO accounting_rule_lines(company_id,event_code,line_role,amount_source,account_id,party_source,priority,is_active)
SELECT c.id,'SALES_INVOICE_IR','DEBIT','NET_TOTAL',ar.id,'CUSTOMER',10,1 FROM companies c JOIN accounts ar ON ar.company_id=c.id AND ar.code='110100';
INSERT IGNORE INTO accounting_rule_lines(company_id,event_code,line_role,amount_source,account_id,party_source,priority,is_active)
SELECT c.id,'SALES_INVOICE_IR','CREDIT','TAXABLE_SALES',sales.id,NULL,20,1 FROM companies c JOIN accounts sales ON sales.company_id=c.id AND sales.code='410100';
INSERT IGNORE INTO accounting_rule_lines(company_id,event_code,line_role,amount_source,account_id,party_source,priority,is_active)
SELECT c.id,'SALES_INVOICE_IR','CREDIT','VAT_TOTAL',vat.id,NULL,30,1 FROM companies c JOIN accounts vat ON vat.company_id=c.id AND vat.code='210300';