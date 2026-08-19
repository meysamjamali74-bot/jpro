ALTER TABLE company_accounting_policies
  ADD COLUMN default_picking_strategy ENUM('FIFO','FEFO','MANUAL') NOT NULL DEFAULT 'FEFO',
  ADD COLUMN block_expired_inventory TINYINT(1) NOT NULL DEFAULT 1,
  ADD COLUMN near_expiry_days INT NOT NULL DEFAULT 30;

CREATE TABLE IF NOT EXISTS sales_fulfillment_allocations (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT UNSIGNED NOT NULL,
  fulfillment_id BIGINT UNSIGNED NOT NULL,
  fulfillment_line_id BIGINT UNSIGNED NOT NULL,
  inventory_balance_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  batch_no VARCHAR(120) NULL,
  expiry_date DATE NULL,
  reserved_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  picked_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  issued_qty DECIMAL(20,4) NOT NULL DEFAULT 0,
  status ENUM('RESERVED','PICKED','ISSUED','RELEASED','CANCELLED') NOT NULL DEFAULT 'RESERVED',
  reserved_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  picked_at DATETIME NULL,
  issued_at DATETIME NULL,
  UNIQUE KEY uq_fulfillment_balance(fulfillment_line_id,inventory_balance_id),
  KEY ix_sfa_fulfillment(fulfillment_id,status),
  KEY ix_sfa_product(product_id,batch_no,expiry_date),
  CONSTRAINT fk_sfa_company FOREIGN KEY(company_id) REFERENCES companies(id),
  CONSTRAINT fk_sfa_fulfillment FOREIGN KEY(fulfillment_id) REFERENCES sales_fulfillments(id),
  CONSTRAINT fk_sfa_line FOREIGN KEY(fulfillment_line_id) REFERENCES sales_fulfillment_lines(id),
  CONSTRAINT fk_sfa_balance FOREIGN KEY(inventory_balance_id) REFERENCES inventory_balances(id),
  CONSTRAINT fk_sfa_product FOREIGN KEY(product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
