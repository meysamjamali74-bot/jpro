-- TARAZPAD Enterprise 1.8 compatibility marker.
--
-- The canonical table remains `trips` throughout the migration chain.
-- No restore rename is required after migration 028. This no-op file remains
-- intentionally so previously recorded migration ordering stays stable.

SELECT 1 AS canonical_trips_table_unchanged;
