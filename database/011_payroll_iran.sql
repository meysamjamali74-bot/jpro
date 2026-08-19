CREATE TABLE IF NOT EXISTS attendance_monthly_summaries (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,company_id BIGINT UNSIGNED NOT NULL,employee_party_id BIGINT UNSIGNED NOT NULL,year_no SMALLINT NOT NULL,month_no TINYINT NOT NULL,calendar_days DECIMAL(8,2) NOT NULL DEFAULT 30,work_days DECIMAL(8,2) NOT NULL DEFAULT 30,paid_leave_days DECIMAL(8,2) NOT NULL DEFAULT 0,unpaid_leave_days DECIMAL(8,2) NOT NULL DEFAULT 0,absence_days DECIMAL(8,2) NOT NULL DEFAULT 0,overtime_hours DECIMAL(10,2) NOT NULL DEFAULT 0,night_hours DECIMAL(10,2) NOT NULL DEFAULT 0,friday_hours DECIMAL(10,2) NOT NULL DEFAULT 0,mission_days DECIMAL(8,2) NOT NULL DEFAULT 0,status ENUM('DRAFT','APPROVED','LOCKED') NOT NULL DEFAULT 'DRAFT',created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 UNIQUE KEY uq_attendance_month(company_id,employee_party_id,year_no,month_no),KEY ix_attendance_period(company_id,year_no,month_no,status),CONSTRAINT fk_att_company FOREIGN KEY(company_id) REFERENCES companies(id),CONSTRAINT fk_att_employee FOREIGN KEY(employee_party_id) REFERENCES parties(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS employee_loans (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,company_id BIGINT UNSIGNED NOT NULL,employee_party_id BIGINT UNSIGNED NOT NULL,loan_no VARCHAR(80) NOT NULL,loan_type ENUM('LOAN','ADVANCE','OTHER') NOT NULL DEFAULT 'LOAN',principal_amount DECIMAL(20,2) NOT NULL,installment_amount DECIMAL(20,2) NOT NULL,start_date DATE NOT NULL,end_date DATE NULL,remaining_amount DECIMAL(20,2) NOT NULL,status ENUM('ACTIVE','PAID','SUSPENDED','CANCELLED') NOT NULL DEFAULT 'ACTIVE',description VARCHAR(500) NULL,UNIQUE KEY uq_employee_loan(company_id,loan_no),KEY ix_loan_employee(company_id,employee_party_id,status),CONSTRAINT fk_loan_company FOREIGN KEY(company_id) REFERENCES companies(id),CONSTRAINT fk_loan_employee FOREIGN KEY(employee_party_id) REFERENCES parties(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS payroll_batches (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,company_id BIGINT UNSIGNED NOT NULL,year_no SMALLINT NOT NULL,month_no TINYINT NOT NULL,title VARCHAR(180) NOT NULL,status ENUM('DRAFT','CALCULATED','REVIEWED','APPROVED','POSTED','PAID','CLOSED') NOT NULL DEFAULT 'DRAFT',legal_parameter_id BIGINT UNSIGNED NULL,total_gross DECIMAL(20,2) NOT NULL DEFAULT 0,total_employee_insurance DECIMAL(20,2) NOT NULL DEFAULT 0,total_employer_insurance DECIMAL(20,2) NOT NULL DEFAULT 0,total_tax DECIMAL(20,2) NOT NULL DEFAULT 0,total_deductions DECIMAL(20,2) NOT NULL DEFAULT 0,total_net DECIMAL(20,2) NOT NULL DEFAULT 0,created_by BIGINT UNSIGNED NOT NULL,reviewed_by BIGINT UNSIGNED NULL,approved_by BIGINT UNSIGNED NULL,posted_at DATETIME NULL,paid_at DATETIME NULL,closed_at DATETIME NULL,created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE KEY uq_payroll_batch(company_id,year_no,month_no),KEY ix_payroll_batch_status(company_id,status,year_no,month_no),CONSTRAINT fk_pb_company FOREIGN KEY(company_id) REFERENCES companies(id),CONSTRAINT fk_pb_param FOREIGN KEY(legal_parameter_id) REFERENCES payroll_legal_parameters(id),CONSTRAINT fk_pb_creator FOREIGN KEY(created_by) REFERENCES users(id),CONSTRAINT fk_pb_reviewer FOREIGN KEY(reviewed_by) REFERENCES users(id),CONSTRAINT fk_pb_approver FOREIGN KEY(approved_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS payroll_slips (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,payroll_batch_id BIGINT UNSIGNED NOT NULL,employee_party_id BIGINT UNSIGNED NOT NULL,employment_contract_id BIGINT UNSIGNED NOT NULL,work_days DECIMAL(8,2) NOT NULL DEFAULT 30,gross_earnings DECIMAL(20,2) NOT NULL DEFAULT 0,insurable_amount DECIMAL(20,2) NOT NULL DEFAULT 0,taxable_amount DECIMAL(20,2) NOT NULL DEFAULT 0,employee_insurance DECIMAL(20,2) NOT NULL DEFAULT 0,employer_insurance DECIMAL(20,2) NOT NULL DEFAULT 0,unemployment_insurance DECIMAL(20,2) NOT NULL DEFAULT 0,salary_tax DECIMAL(20,2) NOT NULL DEFAULT 0,loan_deduction DECIMAL(20,2) NOT NULL DEFAULT 0,other_deductions DECIMAL(20,2) NOT NULL DEFAULT 0,net_pay DECIMAL(20,2) NOT NULL DEFAULT 0,calculation_json JSON NULL,status ENUM('CALCULATED','REVIEWED','APPROVED','POSTED','PAID') NOT NULL DEFAULT 'CALCULATED',created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE KEY uq_payroll_slip(payroll_batch_id,employee_party_id),KEY ix_payroll_employee(employee_party_id,payroll_batch_id),CONSTRAINT fk_ps_batch FOREIGN KEY(payroll_batch_id) REFERENCES payroll_batches(id) ON DELETE CASCADE,CONSTRAINT fk_ps_employee FOREIGN KEY(employee_party_id) REFERENCES parties(id),CONSTRAINT fk_ps_contract FOREIGN KEY(employment_contract_id) REFERENCES employment_contracts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS payroll_slip_lines (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,payroll_slip_id BIGINT UNSIGNED NOT NULL,line_code VARCHAR(80) NOT NULL,title VARCHAR(180) NOT NULL,line_type ENUM('EARNING','DEDUCTION','EMPLOYER_COST') NOT NULL,amount DECIMAL(20,2) NOT NULL,is_insurable TINYINT(1) NOT NULL DEFAULT 0,is_taxable TINYINT(1) NOT NULL DEFAULT 0,source_type VARCHAR(80) NULL,source_id BIGINT UNSIGNED NULL,sort_order INT NOT NULL DEFAULT 100,
 KEY ix_psl_slip(payroll_slip_id,sort_order),CONSTRAINT fk_psl_slip FOREIGN KEY(payroll_slip_id) REFERENCES payroll_slips(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO payroll_legal_parameters(company_id,title,effective_from,effective_to,parameters_json,legal_reference,is_active)
SELECT NULL,'پارامترهای پایه حقوق و دستمزد ۱۴۰۵','2026-03-21','2027-03-20',JSON_OBJECT(
 'minimum_daily_wage',5541850,
 'minimum_monthly_wage_30d',166255500,
 'housing_allowance',30000000,
 'food_allowance',22000000,
 'marriage_allowance',5000000,
 'child_allowance_per_child',16625550,
 'seniority_monthly',5000000,
 'overtime_multiplier',1.4,
 'employee_insurance_rate',7.0,
 'employer_insurance_rate',20.0,
 'unemployment_insurance_rate',3.0,
 'tax_monthly_exemption',400000000,
 'tax_brackets',JSON_ARRAY(
   JSON_OBJECT('from',400000000,'to',800000000,'rate',10),
   JSON_OBJECT('from',800000000,'to',1000000000,'rate',15),
   JSON_OBJECT('from',1000000000,'to',1200000000,'rate',20),
   JSON_OBJECT('from',1200000000,'to',1400000000,'rate',25),
   JSON_OBJECT('from',1400000000,'to',NULL,'rate',30)
 ),
 'deduct_employee_insurance_before_tax',true
),'مصوبات مزدی ۱۴۰۵ و احکام مالیات حقوق؛ تمام پارامترها در نرم‌افزار قابل نسخه‌بندی و اصلاح هستند.',1
WHERE NOT EXISTS(SELECT 1 FROM payroll_legal_parameters WHERE company_id IS NULL AND effective_from='2026-03-21' AND title='پارامترهای پایه حقوق و دستمزد ۱۴۰۵');

INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'610100','هزینه حقوق و دستمزد',3,'DEBIT','EXPENSE',1 FROM companies;
INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'220100','حقوق و دستمزد پرداختنی',3,'CREDIT','LIABILITY',1 FROM companies;
INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'220200','مالیات حقوق پرداختنی',3,'CREDIT','LIABILITY',1 FROM companies;
INSERT IGNORE INTO accounts(company_id,code,title,level_no,nature,account_type,allow_posting)
SELECT id,'220300','حق بیمه تأمین اجتماعی پرداختنی',3,'CREDIT','LIABILITY',1 FROM companies;

INSERT IGNORE INTO accounting_rule_lines(company_id,event_code,line_role,amount_source,account_id,party_source,priority,is_active)
SELECT c.id,'PAYROLL_IR','DEBIT','GROSS_PLUS_EMPLOYER_INSURANCE',exp.id,NULL,10,1 FROM companies c JOIN accounts exp ON exp.company_id=c.id AND exp.code='610100';
INSERT IGNORE INTO accounting_rule_lines(company_id,event_code,line_role,amount_source,account_id,party_source,priority,is_active)
SELECT c.id,'PAYROLL_IR','CREDIT','NET_PAY',pay.id,NULL,20,1 FROM companies c JOIN accounts pay ON pay.company_id=c.id AND pay.code='220100';
INSERT IGNORE INTO accounting_rule_lines(company_id,event_code,line_role,amount_source,account_id,party_source,priority,is_active)
SELECT c.id,'PAYROLL_IR','CREDIT','SALARY_TAX',tax.id,NULL,30,1 FROM companies c JOIN accounts tax ON tax.company_id=c.id AND tax.code='220200';
INSERT IGNORE INTO accounting_rule_lines(company_id,event_code,line_role,amount_source,account_id,party_source,priority,is_active)
SELECT c.id,'PAYROLL_IR','CREDIT','TOTAL_INSURANCE',ins.id,NULL,40,1 FROM companies c JOIN accounts ins ON ins.company_id=c.id AND ins.code='220300';
INSERT IGNORE INTO accounting_rule_lines(company_id,event_code,line_role,amount_source,account_id,party_source,priority,is_active)
SELECT c.id,'PAYROLL_IR','CREDIT','OTHER_DEDUCTIONS',pay.id,NULL,50,1 FROM companies c JOIN accounts pay ON pay.company_id=c.id AND pay.code='220100';