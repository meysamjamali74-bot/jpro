CREATE TABLE IF NOT EXISTS budget_periods (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  budget_id BIGINT UNSIGNED NOT NULL,
  period_no SMALLINT NOT NULL,
  title VARCHAR(120) NOT NULL,
  date_from DATE NOT NULL,
  date_to DATE NOT NULL,
  UNIQUE KEY uq_budget_period(budget_id,period_no),
  KEY ix_budget_period_dates(budget_id,date_from,date_to),
  CONSTRAINT fk_bp_budget FOREIGN KEY(budget_id) REFERENCES budget_headers(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

ALTER TABLE budget_lines
  ADD COLUMN budget_period_id BIGINT UNSIGNED NULL AFTER project_code,
  ADD CONSTRAINT fk_bl_period FOREIGN KEY(budget_period_id) REFERENCES budget_periods(id) ON DELETE CASCADE;

CREATE TABLE IF NOT EXISTS inventory_cost_layers (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  warehouse_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  goods_receipt_line_id BIGINT UNSIGNED NULL,
  layer_date DATETIME NOT NULL,
  original_qty DECIMAL(20,4) NOT NULL,
  remaining_qty DECIMAL(20,4) NOT NULL,
  base_unit_cost DECIMAL(20,6) NOT NULL,
  landed_cost_per_unit DECIMAL(20,6) NOT NULL DEFAULT 0,
  effective_unit_cost DECIMAL(20,6) GENERATED ALWAYS AS (base_unit_cost + landed_cost_per_unit) STORED,
  status ENUM('OPEN','CONSUMED','ADJUSTED') NOT NULL DEFAULT 'OPEN',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_cost_layer_grline(goods_receipt_line_id),
  KEY ix_cost_layer_fifo(company_id,warehouse_id,product_id,status,layer_date,id),
  CONSTRAINT fk_icl_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_icl_warehouse FOREIGN KEY(warehouse_id) REFERENCES warehouses(id),
  CONSTRAINT fk_icl_product FOREIGN KEY(product_id) REFERENCES products(id),
  CONSTRAINT fk_icl_grline FOREIGN KEY(goods_receipt_line_id) REFERENCES goods_receipt_lines(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS inventory_cost_layer_consumptions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  cost_layer_id BIGINT UNSIGNED NOT NULL,
  movement_id BIGINT UNSIGNED NULL,
  source_type VARCHAR(80) NOT NULL,
  source_id BIGINT UNSIGNED NOT NULL,
  consumption_date DATETIME NOT NULL,
  quantity DECIMAL(20,4) NOT NULL,
  unit_cost DECIMAL(20,6) NOT NULL,
  cost_amount DECIMAL(20,2) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_iclc_source(source_type,source_id),
  CONSTRAINT fk_iclc_layer FOREIGN KEY(cost_layer_id) REFERENCES inventory_cost_layers(id),
  CONSTRAINT fk_iclc_movement FOREIGN KEY(movement_id) REFERENCES inventory_movements(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

ALTER TABLE landed_cost_targets
  ADD COLUMN remaining_qty_at_post DECIMAL(20,4) NOT NULL DEFAULT 0,
  ADD COLUMN inventory_portion DECIMAL(20,2) NOT NULL DEFAULT 0,
  ADD COLUMN consumed_portion DECIMAL(20,2) NOT NULL DEFAULT 0;

-- Backfill an initial open cost layer for historical purchase receipt lines where possible.
INSERT IGNORE INTO inventory_cost_layers(company_id,warehouse_id,product_id,goods_receipt_line_id,layer_date,original_qty,remaining_qty,base_unit_cost,status)
SELECT gr.company_id,gr.warehouse_id,l.product_id,l.id,gr.receipt_date,l.accepted_qty,
       LEAST(l.accepted_qty,COALESCE(ib.on_hand_qty,0)),l.unit_cost,
       CASE WHEN LEAST(l.accepted_qty,COALESCE(ib.on_hand_qty,0))<=0 THEN 'CONSUMED' ELSE 'OPEN' END
FROM goods_receipt_lines l
JOIN goods_receipts gr ON gr.id=l.goods_receipt_id
LEFT JOIN inventory_balances ib ON ib.company_id=gr.company_id AND ib.warehouse_id=gr.warehouse_id AND ib.product_id=l.product_id AND ib.batch_no IS NULL AND ib.expiry_date IS NULL
WHERE l.accepted_qty>0;
