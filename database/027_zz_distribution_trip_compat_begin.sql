-- Compatibility bridge for Enterprise 1.5 migration 028.
-- Fresh schemas use `trips`; migration 028 historically referenced
-- `distribution_trips`. Rename only for the narrow migration window.
-- Existing/upgraded schemas are left untouched when both/other states exist.

SET @trz_has_trips := (
  SELECT COUNT(*) FROM information_schema.TABLES
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='trips' AND TABLE_TYPE='BASE TABLE'
);
SET @trz_has_distribution_trips := (
  SELECT COUNT(*) FROM information_schema.TABLES
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='distribution_trips' AND TABLE_TYPE='BASE TABLE'
);
SET @trz_trip_compat_sql := IF(
  @trz_has_trips=1 AND @trz_has_distribution_trips=0,
  'RENAME TABLE trips TO distribution_trips',
  'SELECT 1'
);
PREPARE trz_trip_compat_stmt FROM @trz_trip_compat_sql;
EXECUTE trz_trip_compat_stmt;
DEALLOCATE PREPARE trz_trip_compat_stmt;
