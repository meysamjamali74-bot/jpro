DELIMITER $$

CREATE PROCEDURE sp_tarazpad_consume_fifo(
  IN p_company BIGINT UNSIGNED,
  IN p_warehouse BIGINT UNSIGNED,
  IN p_product BIGINT UNSIGNED,
  IN p_qty DECIMAL(20,4),
  IN p_movement BIGINT UNSIGNED,
  IN p_source_type VARCHAR(80),
  IN p_source_id BIGINT UNSIGNED,
  IN p_date DATETIME
)
BEGIN
  DECLARE v_remaining DECIMAL(20,4) DEFAULT p_qty;
  DECLARE v_layer BIGINT UNSIGNED;
  DECLARE v_layer_qty DECIMAL(20,4);
  DECLARE v_cost DECIMAL(20,6);
  DECLARE v_take DECIMAL(20,4);
  WHILE v_remaining > 0.00005 DO
    SET v_layer = NULL;
    SELECT id,remaining_qty,effective_unit_cost INTO v_layer,v_layer_qty,v_cost
      FROM inventory_cost_layers
      WHERE company_id=p_company AND warehouse_id=p_warehouse AND product_id=p_product
        AND remaining_qty>0.00005 AND status='OPEN'
      ORDER BY layer_date,id LIMIT 1 FOR UPDATE;
    IF v_layer IS NULL THEN
      SET v_remaining = 0;
    ELSE
      SET v_take = LEAST(v_remaining,v_layer_qty);
      INSERT INTO inventory_cost_layer_consumptions(cost_layer_id,movement_id,source_type,source_id,consumption_date,quantity,unit_cost,cost_amount)
      VALUES(v_layer,p_movement,COALESCE(p_source_type,'INVENTORY_MOVEMENT'),COALESCE(p_source_id,p_movement),COALESCE(p_date,NOW()),v_take,v_cost,ROUND(v_take*v_cost,2));
      UPDATE inventory_cost_layers
        SET remaining_qty=remaining_qty-v_take,
            status=CASE WHEN remaining_qty-v_take<=0.00005 THEN 'CONSUMED' ELSE 'OPEN' END
      WHERE id=v_layer;
      SET v_remaining=v_remaining-v_take;
    END IF;
  END WHILE;
END$$

CREATE TRIGGER trg_cost_layer_goods_receipt_insert
AFTER INSERT ON goods_receipt_lines
FOR EACH ROW
BEGIN
  DECLARE v_company BIGINT UNSIGNED;
  DECLARE v_warehouse BIGINT UNSIGNED;
  DECLARE v_date DATETIME;
  SELECT company_id,warehouse_id,receipt_date INTO v_company,v_warehouse,v_date FROM goods_receipts WHERE id=NEW.goods_receipt_id;
  IF NEW.accepted_qty>0 THEN
    INSERT IGNORE INTO inventory_cost_layers(company_id,warehouse_id,product_id,goods_receipt_line_id,layer_date,original_qty,remaining_qty,base_unit_cost,status)
    VALUES(v_company,v_warehouse,NEW.product_id,NEW.id,v_date,NEW.accepted_qty,NEW.accepted_qty,NEW.unit_cost,'OPEN');
  END IF;
END$$

CREATE TRIGGER trg_cost_layer_inventory_out
AFTER INSERT ON inventory_movements
FOR EACH ROW
BEGIN
  DECLARE v_out DECIMAL(20,4) DEFAULT 0;
  IF NEW.quantity < 0 THEN
    SET v_out = ABS(NEW.quantity);
  ELSEIF NEW.movement_type IN ('ISSUE','TRANSFER_OUT','RETURN_OUT','SALE_OUT','TRIP_LOAD') THEN
    SET v_out = NEW.quantity;
  END IF;
  IF v_out > 0.00005 THEN
    CALL sp_tarazpad_consume_fifo(NEW.company_id,NEW.warehouse_id,NEW.product_id,v_out,NEW.id,NEW.source_type,NEW.source_id,NEW.movement_date);
  END IF;
END$$

DELIMITER ;
