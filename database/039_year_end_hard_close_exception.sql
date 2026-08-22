-- TARAZPAD Enterprise year-end HARD_CLOSED compatibility marker.
--
-- Runtime HARD_CLOSED enforcement is implemented in the API guard
-- (apps/api/src/fiscal_lock_guard_v8.js), so normal application migrations do
-- not require MySQL TRIGGER/SUPER privileges. This is required for fresh MySQL
-- 8.4 installations and managed/restricted database users with binary logging
-- enabled.
--
-- Native database-level guards are still installed by the Windows Server
-- installer through installer/windows-server/HardClose-DatabaseGuards.sql using
-- the privileged database setup path. Existing upgraded databases keep any
-- already-installed compatible triggers; this migration intentionally does not
-- DROP or recreate them, preserving upgrade/data compatibility.
--
-- The year-end close workflow remains responsible for its controlled approved
-- close-run exception before the period is HARD_CLOSED.

SELECT 1 AS year_end_hard_close_application_guard_enabled;
