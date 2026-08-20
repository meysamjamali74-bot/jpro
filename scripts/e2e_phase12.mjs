const base=process.env.TARAZPAD_URL||'http://127.0.0.1:8080';
const adminEmail=process.env.TARAZPAD_ADMIN_EMAIL||'strict@tarazpad.test';
const adminPassword=process.env.TARAZPAD_ADMIN_PASSWORD||'Strong_Strict_2026!';
const log=(step,data='')=>console.log(`[E2E] ${step}${data?` :: ${typeof data==='string'?data:JSON.stringify(data)}`:''}`);
const assert=(v,msg,data)=>{if(!v){const e=new Error(msg);e.data=data;throw e}};
async function req(path,{token,method='GET',body}={}){const r=await fetch(base+path,{method,headers:{...(token?{authorization:`Bearer ${token}`}:{}) ,...(body!==undefined?{'content-type':'application/json'}:{})},body:body===undefined?undefined:JSON.stringify(body)});const text=await r.text();let data;try{data=JSON.parse(text)}catch{data=text}if(!r.ok){const e=new Error(`${method} ${path} -> ${r.status} ${typeof data==='string'?data:JSON.stringify(data)}`);e.status=r.status;e.data=data;throw e}return data}
async function login(email,password){const x=await req('/api/auth/login',{method:'POST',body:{email,password}});assert(x.token,`ورود ${email} توکن نداد`,x);return x.token}
async function createUser(admin,fullName,email,password,roleCodes){return req('/api/iran/admin/users',{token:admin,method:'POST',body:{fullName,email,password,roleCodes}})}
async function main(){
 log('START');
 const health=await req('/api/health');assert(health.ok,'Health ناموفق',health);log('HEALTH_OK',health.version);
 const admin=await login(adminEmail,adminPassword);log('ADMIN_LOGIN_OK');
 const stamp=Date.now().toString().slice(-8);
 const salesEmail=`sales${stamp}@tarazpad.test`,reviewEmail=`review${stamp}@tarazpad.test`,finEmail=`finance${stamp}@tarazpad.test`,logEmail=`log${stamp}@tarazpad.test`;
 const salesU=await createUser(admin,'فروشنده کنترل',salesEmail,'Strong_Sales_2026!',['SALES_PERSON']);
 const reviewU=await createUser(admin,'بازبین فروش',reviewEmail,'Strong_Review_2026!',['SALES_MANAGER']);
 const finU=await createUser(admin,'مدیر مالی کنترل',finEmail,'Strong_Finance_2026!',['FINANCE_MANAGER']);
 const logU=await createUser(admin,'مدیر لجستیک کنترل',logEmail,'Strong_Logistics_2026!',['LOGISTICS_MANAGER']);
 const sales=await login(salesEmail,'Strong_Sales_2026!'),review=await login(reviewEmail,'Strong_Review_2026!'),fin=await login(finEmail,'Strong_Finance_2026!'),logistics=await login(logEmail,'Strong_Logistics_2026!');
 log('USERS_OK',{sales:salesU.id,review:reviewU.id,finance:finU.id,logistics:logU.id});

 const bank=await req('/api/treasury/bank-accounts',{token:fin,method:'POST',body:{code:`BANK-${stamp}`,bankName:'بانک تست',accountTitle:'حساب جاری تست',accountNo:`12345${stamp}`,openingBalance:0}});log('BANK_OK',bank);
 const wh=await req('/api/inventory/warehouses',{token:admin,method:'POST',body:{code:`WH-${stamp}`,name:'انبار تست کنترل',warehouseType:'GENERAL'}});log('WAREHOUSE_OK',wh);
 const customer=await req('/api/iran/parties',{token:admin,method:'POST',body:{name:`مشتری کنترل ${stamp}`,partyType:'LEGAL',code:`CUS-${stamp}`,nationalId:`140${stamp}11`,economicCode:`411${stamp}111`,postalCode:`14${stamp}`,roles:['CUSTOMER']}});log('CUSTOMER_OK',customer.id);
 const supplier=await req('/api/iran/parties',{token:admin,method:'POST',body:{name:`تأمین‌کننده کنترل ${stamp}`,partyType:'LEGAL',code:`SUP-${stamp}`,nationalId:`141${stamp}11`,economicCode:`422${stamp}111`,postalCode:`15${stamp}`,roles:['SUPPLIER']}});log('SUPPLIER_OK',supplier.id);
 const product=await req('/api/iran/products',{token:admin,method:'POST',body:{sku:`PR-${stamp}`,name:'کالای کنترل پخش',unit:'عدد',purchasePrice:70000,salePrice:100000,vatStatus:'STANDARD',defaultVatRate:10,productType:'GOODS'}});log('PRODUCT_OK',product.id);

 const po=await req('/api/procurement/orders',{token:admin,method:'POST',body:{supplierPartyId:supplier.id,warehouseId:wh.id,poDate:'2026-08-10',lines:[{productId:product.id,qty:10,unitPrice:70000,discount:0,tax:0}]}});log('PO_CREATED',po);
 const submitted=await req(`/api/procurement/orders/${po.id}/submit`,{token:admin,method:'POST',body:{}});assert(submitted.approvalRequestId,'Approval request ساخته نشد',submitted);log('PO_SUBMITTED',submitted);
 const decision=await req(`/api/workflow/approvals/${submitted.approvalRequestId}/decision`,{token:fin,method:'POST',body:{action:'APPROVE'}});assert(decision.status==='APPROVED','PO تأیید نشد',decision);log('PO_APPROVED');
 const ctx=await req(`/api/iran/procurement/context?purchaseOrderId=${po.id}`,{token:admin});assert(ctx.poLines?.length,'PO line پیدا نشد',ctx);const pol=ctx.poLines[0];log('PO_CONTEXT_OK',pol.id);
 const gr=await req('/api/procurement/goods-receipts',{token:admin,method:'POST',body:{purchaseOrderId:po.id,warehouseId:wh.id,receiptDate:'2026-08-11',lines:[{purchaseOrderLineId:pol.id,receivedQty:10,acceptedQty:10,unitCost:70000}]}});log('GR_CREATED',gr);
 const grPost=await req(`/api/iran/goods-receipts/${gr.id}/post`,{token:fin,method:'POST',body:{}});assert(Number(grPost.receivedValue)===700000,'ارزش رسید نادرست',grPost);log('GR_POSTED',grPost);
 const pi=await req('/api/iran/purchase-invoices/auto',{token:fin,method:'POST',body:{supplierPartyId:supplier.id,invoiceDate:'2026-08-12',invoiceClassification:'NON_OFFICIAL',purchaseKind:'GOODS',purchaseOrderId:po.id,goodsReceiptId:gr.id,lines:[{productId:product.id,qty:10,unitPrice:70000,vatStatus:'STANDARD',vatRate:10}]}});log('PI_CREATED',pi);
 const match=await req(`/api/iran/purchase-invoices/${pi.id}/match`,{token:fin,method:'POST',body:{}});assert(match.status==='APPROVED','3-way match ناموفق',match);log('PI_MATCHED',match);
 const piPost=await req(`/api/iran/purchase-invoices/${pi.id}/post`,{token:fin,method:'POST',body:{}});assert(piPost.ok,'ثبت فاکتور خرید ناموفق',piPost);log('PI_POSTED',piPost);
 const payment=await req('/api/iran/treasury/payments',{token:fin,method:'POST',body:{partyId:supplier.id,paymentDate:'2026-08-13',method:'BANK',bankAccountId:bank.id,amount:770000,idempotencyKey:`E2E-PAY-${stamp}`,allocations:[{purchaseInvoiceId:pi.id,amount:770000}]}});assert(payment.id,'پرداخت ساخته نشد',payment);log('PAYMENT_OK',payment);

 async function sale(date){const inv=await req('/api/iran/sales-invoices',{token:sales,method:'POST',body:{customerPartyId:customer.id,invoiceDate:date,invoiceClassification:'NON_OFFICIAL',settlementType:'CREDIT',salespersonUserId:salesU.id,lines:[{productId:product.id,qty:1,unitPrice:100000}]}});log('SALE_CREATED',inv);const posted=await req(`/api/iran/sales-invoices/${inv.id}/post`,{token:fin,method:'POST',body:{}});assert(Number(posted.amounts?.COGS_TOTAL)===70000,'COGS باید 70000 باشد',posted);assert(Number(posted.grossProfit)===30000,'سود ناخالص باید 30000 باشد',posted);log('SALE_POSTED',posted);return inv;}
 const inv1=await sale('2026-08-14');
 const rcv1=await req('/api/iran/treasury/receipts',{token:fin,method:'POST',body:{partyId:customer.id,receiptDate:'2026-08-15',method:'BANK',bankAccountId:bank.id,amount:110000,referenceNo:`BANK-R1-${stamp}`,idempotencyKey:`E2E-R1-${stamp}`,allocations:[{salesInvoiceId:inv1.id,amount:110000}]}});log('RECEIPT1_OK',rcv1);
 const preview=await req('/api/iran/treasury/bank-statements/preview',{token:fin,method:'POST',body:{bankAccountId:bank.id,rows:[{statementDate:'2026-08-15',debit:0,credit:110000,referenceNo:`BANK-R1-${stamp}`,description:'واریز مشتری'}]}});assert(preview.valid===1&&preview.duplicates===0,'Preview بانک نادرست',preview);log('BANK_PREVIEW_OK',preview);
 const imp=await req('/api/iran/treasury/bank-statements/import',{token:fin,method:'POST',body:{bankAccountId:bank.id,fileName:`e2e-${stamp}.csv`,rows:[{statementDate:'2026-08-15',debit:0,credit:110000,referenceNo:`BANK-R1-${stamp}`,description:'واریز مشتری'}]}});assert(imp.imported===1,'Import بانک باید 1 ردیف باشد',imp);log('BANK_IMPORT_OK',imp);
 const recRows=await req(`/api/iran/treasury/reconciliation?bankAccountId=${bank.id}&status=UNMATCHED`,{token:fin});assert(recRows.length,'ردیف بانک تطبیق‌نشده پیدا نشد',recRows);const bl=recRows[0];
 const sug=await req(`/api/iran/treasury/reconciliation/${bl.id}/suggest`,{token:fin,method:'POST',body:{dateToleranceDays:3,amountTolerance:1}});assert(sug.suggestions?.length,'پیشنهاد تطبیق پیدا نشد',sug);log('BANK_SUGGEST_OK',sug.suggestions[0]);
 const conf=await req(`/api/iran/treasury/reconciliation/${bl.id}/confirm`,{token:fin,method:'POST',body:{entityType:'RECEIPT',entityId:rcv1.id,amountTolerance:1}});assert(conf.entityType==='RECEIPT','تطبیق قطعی نشد',conf);log('BANK_RECONCILED',conf);

 const inv2=await sale('2026-08-16');
 const route=await req('/api/logistics/routes',{token:logistics,method:'POST',body:{code:`R-${stamp}`,name:'مسیر کنترل',salespersonUserId:salesU.id,customerPartyIds:[customer.id]}});log('ROUTE_OK',route);
 const vehicle=await req('/api/logistics/vehicles',{token:logistics,method:'POST',body:{plateNo:`11الف${stamp.slice(-3)}-11`,vehicleType:'وانت سردخانه',capacityWeight:1000,refrigerated:true}});log('VEHICLE_OK',vehicle);
 const trip=await req('/api/iran/distribution/trips',{token:logistics,method:'POST',body:{tripDate:'2026-08-17',routeId:route.id,vehicleId:vehicle.id,driverUserId:logU.id,expectedCollection:110000,stops:[{customerPartyId:customer.id,salesInvoiceId:inv2.id}]}});log('TRIP_CREATED',trip);
 const load=await req(`/api/iran/distribution/trips/${trip.id}/load`,{token:logistics,method:'POST',body:{lines:[{warehouseId:wh.id,productId:product.id,quantity:1}]}});assert(load.ok,'بارگیری ناموفق',load);log('TRIP_LOADED');
 for(const [status,extra] of [['GATE_CHECK',{}],['DISPATCHED',{odometerOut:10000}],['IN_ROUTE',{}]]){const x=await req(`/api/iran/distribution/trips/${trip.id}/transition`,{token:logistics,method:'POST',body:{status,...extra}});assert(x.status===status,`وضعیت سفر ${status} نشد`,x);log(`TRIP_${status}`)}
 const td=await req(`/api/iran/distribution/trips/${trip.id}`,{token:logistics});assert(td.stops?.length,'توقف سفر پیدا نشد',td);const stop=td.stops[0];
 await req(`/api/iran/distribution/stops/${stop.id}/arrive`,{token:logistics,method:'POST',body:{latitude:35.7,longitude:51.4}});log('STOP_ARRIVED');
 const delivered=await req(`/api/iran/distribution/stops/${stop.id}/deliver`,{token:logistics,method:'POST',body:{status:'DELIVERED',receiverName:'تحویل‌گیرنده تست',signatureRef:'pod://e2e/signature',photoRef:'pod://e2e/photo',lines:[{productId:product.id,deliveredQty:1,returnedQty:0,damagedQty:0}]}});assert(delivered.stopStatus==='DELIVERED'&&Number(delivered.inventoryVariance)===0,'POD/تحویل ناموفق',delivered);log('POD_DELIVERED',delivered);
 const col=await req(`/api/iran/distribution/trips/${trip.id}/collections`,{token:logistics,method:'POST',body:{customerPartyId:customer.id,method:'CASH',amount:110000,referenceNo:`TRIP-CASH-${stamp}`}});log('TRIP_COLLECTION_OK',col);
 const hand=await req(`/api/iran/distribution/collections/${col.id}/handover`,{token:fin,method:'POST',body:{}});assert(hand.ok&&Number(hand.allocated)===110000,'تحویل وصول به خزانه ناموفق',hand);log('COLLECTION_HANDOVER_OK',hand);
 const settled=await req(`/api/iran/distribution/trips/${trip.id}/settle`,{token:logistics,method:'POST',body:{odometerIn:10025}});assert(settled.status==='CLOSED'&&Number(settled.inventoryVariance)===0&&Number(settled.financialDifference)===0&&Number(settled.unhanded)===0,'تسویه سفر ناموفق',settled);log('TRIP_SETTLED',settled);

 const ruleGP=await req('/api/iran/commissions/rules',{token:admin,method:'POST',body:{title:`سود وصول‌شده ${stamp}`,basis:'GROSS_PROFIT',baseRate:5,collectionBased:true,assignments:[{salespersonUserId:salesU.id,effectiveFrom:'2026-08-01'}]}});const ruleCol=await req('/api/iran/commissions/rules',{token:admin,method:'POST',body:{title:`وصول ${stamp}`,basis:'COLLECTION',baseRate:2,assignments:[{salespersonUserId:salesU.id,effectiveFrom:'2026-08-01'}]}});log('COMMISSION_RULES_OK',{ruleGP:ruleGP.id,ruleCol:ruleCol.id});
 const run=await req('/api/iran/commissions/run',{token:admin,method:'POST',body:{periodStart:'2026-08-01',periodEnd:'2026-08-31',salespersonUserId:salesU.id}});assert(run.length===2,'باید دو نتیجه پورسانت باشد',run);const gp=run.find(x=>x.basis==='GROSS_PROFIT'),coll=run.find(x=>x.basis==='COLLECTION');assert(gp&&Number(gp.grossProfit)===60000, 'سود ناخالص پورسانت نادرست',gp);assert(coll&&Number(coll.collected)===200000,'وصول پورسانت باید 200000 باشد',coll);log('COMMISSION_CALCULATED',run);
 const reviewed=await req(`/api/iran/commissions/results/${gp.id}/review`,{token:review,method:'POST',body:{}});assert(reviewed.status==='REVIEWED','بازبینی پورسانت ناموفق',reviewed);const approved=await req(`/api/iran/commissions/results/${gp.id}/approve`,{token:fin,method:'POST',body:{}});assert(approved.status==='APPROVED','تأیید پورسانت ناموفق',approved);log('COMMISSION_SOD_OK');
 const lines=await req(`/api/iran/commissions/results/${gp.id}/lines`,{token:fin});assert(lines.length===2,'ریز پورسانت باید دو فاکتور باشد',lines);log('COMMISSION_LINES_OK');

 const tb=await req('/api/finance/trial-balance',{token:fin});const debit=tb.reduce((s,x)=>s+Number(x.debit||0),0),credit=tb.reduce((s,x)=>s+Number(x.credit||0),0);assert(Math.abs(debit-credit)<1,'تراز کل سیستم متوازن نیست',{debit,credit});log('TRIAL_BALANCE_OK',{debit,credit});
 log('PASS');
}
main().catch(e=>{console.error(`[E2E][FAIL] ${e.message}`);if(e.data)console.error('[E2E][DATA]',JSON.stringify(e.data,null,2));process.exit(1)});
