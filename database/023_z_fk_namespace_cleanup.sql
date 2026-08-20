-- MySQL requires foreign-key constraint names to be unique within a schema.
-- Some legacy Tarazpad databases used commission_rule_assignments with the
-- generic fk_ca_company constraint. Fresh installations no longer create that
-- legacy table (the current model uses commission_assignments), so this
-- migration must be a safe no-op when the legacy object is absent.

SET @trz_legacy_table_exists := (
  SELECT COUNT(*)
  FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'commission_rule_assignments'
);

SET @trz_old_fk_exists := (
  SELECT COUNT(*)
  FROM information_schema.TABLE_CONSTRAINTS
  WHERE CONSTRAINT_SCHEMA = DATABASE()
    AND TABLE_NAME = 'commission_rule_assignments'
    AND CONSTRAINT_NAME = 'fk_ca_company'
    AND CONSTRAINT_TYPE = 'FOREIGN KEY'
);

SET @trz_drop_old_fk_sql := IF(
  @trz_legacy_table_exists > 0 AND @trz_old_fk_exists > 0,
  'ALTER TABLE commission_rule_assignments DROP FOREIGN KEY fk_ca_company',
  'SELECT 1'
);
PREPARE trz_stmt FROM @trz_drop_old_fk_sql;
EXECUTE trz_stmt;
DEALLOCATE PREPARE trz_stmt;

SET @trz_new_fk_exists := (
  SELECT COUNT(*)
  FROM information_schema.TABLE_CONSTRAINTS
  WHERE CONSTRAINT_SCHEMA = DATABASE()
    AND TABLE_NAME = 'commission_rule_assignments'
    AND CONSTRAINT_NAME = 'fk_comm_assignment_company'
    AND CONSTRAINT_TYPE = 'FOREIGN KEY'
);

SET @trz_add_new_fk_sql := IF(
  @trz_legacy_table_exists > 0 AND @trz_new_fk_exists = 0,
  'ALTER TABLE commission_rule_assignments ADD CONSTRAINT fk_comm_assignment_company FOREIGN KEY(company_id) REFERENCES companies(id)',
  'SELECT 1'
);
PREPARE trz_stmt FROM @trz_add_new_fk_sql;
EXECUTE trz_stmt;
DEALLOCATE PREPARE trz_stmt;
