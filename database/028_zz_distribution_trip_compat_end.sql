-- End of the narrow compatibility window opened by migration 027_zz.
-- On a fresh schema the legacy alias is renamed back to the canonical `trips`
-- name. MySQL updates foreign-key metadata to follow the renamed table.

SET @trz_has_trips := (
  SELECT COUNT(*) FROM information_schema.TABLES
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='trips' AND TABLE_TYPE='BASE TABLE'
);
SET @trz_has_distribution_trips := (
  SELECT COUNT(*) FROM information_schema.TABLES
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='distribution_trips' AND TABLE_TYPE='BASE TABLE'
);
SET @trz_trip_restore_sql := IF(
  @trz_has_distribution_trips=1 AND @trz_has_trips=0,
  'RENAME TABLE distribution_trips TO trips',
  'SELECT 1'
);
PREPARE trz_trip_restore_stmt FROM @trz_trip_restore_sql;
EXECUTE trz_trip_restore_stmt;
DEALLOCATE PREPARE trz_trip_restore_stmt;
