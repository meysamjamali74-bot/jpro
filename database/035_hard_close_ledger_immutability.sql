-- TARAZPAD hard-close compatibility marker.
-- Journal immutability for HARD_CLOSED periods is enforced by the application
-- guard on every supported write path. Native Windows installations additionally
-- install database-level triggers with the local MySQL administrative account.
-- Keeping privileged CREATE TRIGGER statements out of the portable migration
-- chain allows fresh installs on managed/restricted MySQL 8.4 without SUPER.

SELECT 1 AS hard_close_application_guard_enabled;
