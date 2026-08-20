-- MySQL requires foreign-key constraint names to be unique within a schema.
-- Older Tarazpad migrations used the generic name fk_ca_company for a
-- pre-CRM relation. Migration 024 also historically used that name for
-- crm_activities. Preserve the earlier relationship, but give it a stable,
-- table-scoped name before 024 is applied. Fresh and upgraded databases must
-- both be safe and idempotent.

SET @trz_fk_table := NULL;
SET @trz_fk_column := NULL;
SET @trz_fk_ref_table := NULL;
SET @trz_fk_ref_column := NULL;
SET @trz_fk_update_rule := 'RESTRICT';
SET @trz_fk_delete_rule := 'RESTRICT';

SELECT k.TABLE_NAME,
       k.COLUMN_NAME,
       k.REFERENCED_TABLE_NAME,
       k.REFERENCED_COLUMN_NAME,
       r.UPDATE_RULE,
       r.DELETE_RULE
INTO @trz_fk_table,
     @trz_fk_column,
     @trz_fk_ref_table,
     @trz_fk_ref_column,
     @trz_fk_update_rule,
     @trz_fk_delete_rule
FROM information_schema.KEY_COLUMN_USAGE k
JOIN information_schema.REFERENTIAL_CONSTRAINTS r
  ON r.CONSTRAINT_SCHEMA=k.CONSTRAINT_SCHEMA
 AND r.CONSTRAINT_NAME=k.CONSTRAINT_NAME
 AND r.TABLE_NAME=k.TABLE_NAME
WHERE k.CONSTRAINT_SCHEMA=DATABASE()
  AND k.CONSTRAINT_NAME='fk_ca_company'
  AND k.REFERENCED_TABLE_NAME IS NOT NULL
ORDER BY k.TABLE_NAME,k.ORDINAL_POSITION
LIMIT 1;

SET @trz_has_generic_fk := IF(@trz_fk_table IS NULL,0,1);
SET @trz_new_fk_name := IF(
  @trz_has_generic_fk=1,
  LEFT(CONCAT('fk_',REPLACE(@trz_fk_table,'`',''),'_company_v8'),64),
  NULL
);

SET @trz_new_fk_exists := IF(
  @trz_has_generic_fk=1,
  (SELECT COUNT(*)
     FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA=DATABASE()
      AND TABLE_NAME=@trz_fk_table
      AND CONSTRAINT_NAME=@trz_new_fk_name
      AND CONSTRAINT_TYPE='FOREIGN KEY'),
  0
);

SET @trz_drop_generic_fk_sql := IF(
  @trz_has_generic_fk=1,
  CONCAT('ALTER TABLE `',REPLACE(@trz_fk_table,'`','``'),'` DROP FOREIGN KEY `fk_ca_company`'),
  'SELECT 1'
);
PREPARE trz_stmt FROM @trz_drop_generic_fk_sql;
EXECUTE trz_stmt;
DEALLOCATE PREPARE trz_stmt;

SET @trz_add_namespaced_fk_sql := IF(
  @trz_has_generic_fk=1 AND @trz_new_fk_exists=0,
  CONCAT(
    'ALTER TABLE `',REPLACE(@trz_fk_table,'`','``'),'` ',
    'ADD CONSTRAINT `',REPLACE(@trz_new_fk_name,'`','``'),'` ',
    'FOREIGN KEY (`',REPLACE(@trz_fk_column,'`','``'),'`) ',
    'REFERENCES `',REPLACE(@trz_fk_ref_table,'`','``'),'` (`',REPLACE(@trz_fk_ref_column,'`','``'),'`) ',
    'ON UPDATE ',@trz_fk_update_rule,' ON DELETE ',@trz_fk_delete_rule
  ),
  'SELECT 1'
);
PREPARE trz_stmt FROM @trz_add_namespaced_fk_sql;
EXECUTE trz_stmt;
DEALLOCATE PREPARE trz_stmt;
