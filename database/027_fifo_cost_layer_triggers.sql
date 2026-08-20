-- TARAZPAD Enterprise FIFO migration compatibility marker.
--
-- FIFO costing is intentionally implemented in the transactional backend
-- (apps/api/src/fifo_costing_v8.js) instead of MySQL PROCEDURE/TRIGGER objects.
-- This keeps fresh installations compatible with managed/cloud MySQL and with
-- restricted application users that do not have SUPER/TRIGGER privileges.
--
-- Existing upgraded databases that already contain the legacy FIFO trigger are
-- still supported: the backend detects any consumption rows created for the
-- movement and will not consume the same cost layers twice.
--
-- The durable schema objects (inventory_cost_layers and
-- inventory_cost_layer_consumptions) are created by migration 023.
-- No privileged DDL is required here.

SELECT 1 AS fifo_backend_costing_enabled;
