-- TARAZPAD hard-close header compatibility marker.
-- The portable migration chain intentionally contains no CREATE TRIGGER DDL.
-- Application-level period guards are mandatory; native Windows installation
-- adds the database defense-in-depth trigger set using the local admin account.

SELECT 1 AS hard_close_header_application_guard_enabled;
