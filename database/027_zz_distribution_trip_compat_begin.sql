-- TARAZPAD Enterprise 1.8 compatibility marker.
--
-- The canonical distribution trip table is `trips`.
-- Migration 028 now references `trips` directly, so no temporary rename is
-- permitted here. Keeping this migration as a no-op preserves ordered migration
-- history for databases that have already recorded the filename.
--
-- Older installations that still contain a legacy `distribution_trips` table
-- are handled by explicit upgrade migrations; Fresh Install must never rename
-- the canonical `trips` table before migration 028.

SELECT 1 AS canonical_trips_table_preserved;
