-- TARAZPAD Enterprise 1.8 compatibility: extend existing Iran party contact/address master data.
-- 007 already owns these tables; 1.8 extends them instead of creating a parallel model.

ALTER TABLE party_contacts
  MODIFY COLUMN full_name VARCHAR(180) NULL,
  ADD COLUMN contact_type ENUM('MOBILE','PHONE','FAX','EMAIL','WHATSAPP','OTHER') NULL AFTER party_id,
  ADD COLUMN label VARCHAR(80) NULL AFTER contact_type,
  ADD COLUMN contact_value VARCHAR(250) NULL AFTER label,
  ADD COLUMN sort_order INT NOT NULL DEFAULT 0 AFTER notes;

UPDATE party_contacts
SET contact_type = CASE
      WHEN mobile IS NOT NULL AND mobile<>'' THEN 'MOBILE'
      WHEN phone IS NOT NULL AND phone<>'' THEN 'PHONE'
      WHEN email IS NOT NULL AND email<>'' THEN 'EMAIL'
      ELSE 'OTHER' END,
    label = COALESCE(NULLIF(job_title,''),NULLIF(full_name,''),'تماس'),
    contact_value = COALESCE(NULLIF(mobile,''),NULLIF(phone,''),NULLIF(email,''),'')
WHERE contact_type IS NULL;

ALTER TABLE party_addresses
  MODIFY COLUMN address TEXT NULL,
  MODIFY COLUMN address_type ENUM('MAIN','BILLING','SHIPPING','DELIVERY','WORK','OTHER') NOT NULL DEFAULT 'MAIN',
  ADD COLUMN address_text VARCHAR(1000) NULL AFTER address,
  ADD COLUMN latitude DECIMAL(10,7) NULL AFTER phone,
  ADD COLUMN longitude DECIMAL(10,7) NULL AFTER latitude,
  ADD COLUMN is_primary TINYINT(1) NOT NULL DEFAULT 0 AFTER is_default;

UPDATE party_addresses
SET address_text=address,
    is_primary=is_default
WHERE address_text IS NULL;
