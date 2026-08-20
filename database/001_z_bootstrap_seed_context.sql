-- This migration runs immediately after 001_core.sql on a completely empty installation.
-- It is intentionally a no-op on existing installations.

INSERT INTO companies(code,name,base_currency,timezone,is_active)
SELECT 'TRZ','ترازپاد','IRR','Asia/Tehran',1
WHERE NOT EXISTS (SELECT 1 FROM companies);

INSERT INTO users(company_id,branch_id,full_name,email,password_hash,is_active)
SELECT c.id,NULL,'کاربر سیستمی مهاجرت','__migration__@tarazpad.local',
       '$2b$12$00000000000000000000000000000000000000000000000000000',0
FROM companies c
WHERE c.code='TRZ' AND NOT EXISTS (SELECT 1 FROM users)
LIMIT 1;
