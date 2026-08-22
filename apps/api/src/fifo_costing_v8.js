const n=v=>Number(v||0);
const EPS=0.00005;

function fifoError(message,details=null){
  const e=new Error(message);
  e.status=422;
  e.details=details;
  throw e;
}

export async function ensureFifoLayers(conn,companyId,warehouseId,productId){
  // FIFO layers are created lazily inside the same transaction that consumes them.
  // Only operationally accepted receipts are eligible; draft/cancelled/rejected
  // receipts must never become an inventory cost source.
  // Existing/upgraded databases are safe because goods_receipt_line_id is unique
  // and INSERT IGNORE never resets an already-consumed layer.
  await conn.execute(`
    INSERT IGNORE INTO inventory_cost_layers(
      company_id,warehouse_id,product_id,goods_receipt_line_id,layer_date,
      original_qty,remaining_qty,base_unit_cost,status
    )
    SELECT gr.company_id,gr.warehouse_id,l.product_id,l.id,gr.receipt_date,
           l.accepted_qty,l.accepted_qty,l.unit_cost,
           CASE WHEN l.accepted_qty<=? THEN 'CONSUMED' ELSE 'OPEN' END
      FROM goods_receipt_lines l
      JOIN goods_receipts gr ON gr.id=l.goods_receipt_id
     WHERE gr.company_id=? AND gr.warehouse_id=? AND l.product_id=?
       AND gr.status IN ('RECEIVED','QC','PUTAWAY','CLOSED')
       AND l.accepted_qty>?
     ORDER BY gr.receipt_date,l.id
  `,[EPS,companyId,warehouseId,productId,EPS]);
}

export async function consumeFifo(conn,{companyId,warehouseId,productId,quantity,movementId,sourceType='INVENTORY_MOVEMENT',sourceId=null,consumptionDate=null}){
  const required=n(quantity);
  if(required<=EPS)return{quantity:0,cost:0,unitCost:0,layers:[]};

  // Upgrade compatibility: older installations may already have the legacy
  // AFTER INSERT trigger. If it consumed this movement, treat those rows as
  // authoritative and do not consume the same FIFO layers a second time.
  const [existing]=await conn.execute(`
    SELECT cost_layer_id layer_id,quantity,unit_cost,cost_amount
      FROM inventory_cost_layer_consumptions
     WHERE movement_id=?
     ORDER BY id
     FOR UPDATE
  `,[movementId]);
  if(existing.length){
    const existingQty=existing.reduce((s,x)=>s+n(x.quantity),0);
    const existingCost=existing.reduce((s,x)=>s+n(x.cost_amount),0);
    if(existingQty+EPS<required){
      fifoError('مصرف FIFO ثبت‌شده برای این حرکت ناقص است.',{movementId,required,costed:existingQty});
    }
    if(existingQty>required+EPS){
      fifoError('مصرف FIFO ثبت‌شده برای این حرکت بیش از مقدار خروج است.',{movementId,required,costed:existingQty});
    }
    return{
      quantity:existingQty,
      cost:Math.round(existingCost*100)/100,
      unitCost:existingQty?existingCost/existingQty:0,
      legacyTrigger:true,
      layers:existing.map(x=>({layerId:x.layer_id,quantity:n(x.quantity),unitCost:n(x.unit_cost),cost:n(x.cost_amount)}))
    };
  }

  await ensureFifoLayers(conn,companyId,warehouseId,productId);

  const [layers]=await conn.execute(`
    SELECT id,remaining_qty,effective_unit_cost
      FROM inventory_cost_layers
     WHERE company_id=? AND warehouse_id=? AND product_id=?
       AND status='OPEN' AND remaining_qty>?
     ORDER BY layer_date,id
     FOR UPDATE
  `,[companyId,warehouseId,productId,EPS]);

  const available=layers.reduce((s,x)=>s+n(x.remaining_qty),0);
  if(available+EPS<required){
    fifoError('لایه بهای FIFO برای خروج کافی نیست.',{productId,warehouseId,required,available});
  }

  let remaining=required,totalCost=0;
  const consumed=[];
  for(const layer of layers){
    if(remaining<=EPS)break;
    const layerQty=n(layer.remaining_qty);
    const take=Math.min(remaining,layerQty);
    if(take<=EPS)continue;
    const unitCost=n(layer.effective_unit_cost);
    const cost=Math.round(take*unitCost*100)/100;
    const newRemaining=Math.max(0,layerQty-take);

    await conn.execute(`
      INSERT INTO inventory_cost_layer_consumptions(
        cost_layer_id,movement_id,source_type,source_id,consumption_date,
        quantity,unit_cost,cost_amount
      ) VALUES (?,?,?,?,COALESCE(?,NOW()),?,?,?)
    `,[layer.id,movementId,sourceType,sourceId??movementId,consumptionDate,take,unitCost,cost]);

    await conn.execute(`
      UPDATE inventory_cost_layers
         SET remaining_qty=?,status=?
       WHERE id=?
    `,[newRemaining,newRemaining<=EPS?'CONSUMED':'OPEN',layer.id]);

    consumed.push({layerId:layer.id,quantity:take,unitCost,cost});
    totalCost+=cost;
    remaining-=take;
  }

  if(remaining>EPS){
    fifoError('مصرف FIFO ناقص ماند و تراکنش باید برگشت داده شود.',{productId,required,remaining});
  }

  return{
    quantity:required,
    cost:Math.round(totalCost*100)/100,
    unitCost:required?totalCost/required:0,
    legacyTrigger:false,
    layers:consumed
  };
}
