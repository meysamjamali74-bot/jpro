-- TARAZPAD Enterprise FIFO migration compatibility marker.
-- FIFO costing is implemented in the transactional backend instead of MySQL
-- PROCEDURE/TRIGGER objects so fresh installs do not require SUPER/TRIGGER grants.
-- Durable FIFO tables are created by migration 023.
SELECT 1 AS fifo_backend_costing_enabled;
