-- Upgrade the core fiscal_years table before Enterprise 1.6 close/reporting objects.
-- 001_core.sql already creates fiscal_years, so 033 CREATE TABLE IF NOT EXISTS cannot add these columns.

ALTER TABLE fiscal_years
  DROP FOREIGN KEY fk_fy_company,
  ADD COLUMN year_no INT NULL AFTER company_id,
  ADD COLUMN closed_by BIGINT UNSIGNED NULL AFTER status,
  ADD COLUMN closed_at DATETIME NULL AFTER closed_by,
  ADD CONSTRAINT fk_fy_core_company FOREIGN KEY(company_id) REFERENCES companies(id),
  ADD CONSTRAINT fk_fy_core_closer FOREIGN KEY(closed_by) REFERENCES users(id);

-- Preserve existing installations. A fiscal year created before this migration receives a deterministic
-- fallback based on its stored start date; users can subsequently correct the display year if required.
UPDATE fiscal_years SET year_no=YEAR(start_date) WHERE year_no IS NULL;

ALTER TABLE fiscal_years
  MODIFY COLUMN year_no INT NOT NULL,
  ADD UNIQUE KEY uq_fy_company_year(company_id,year_no);
