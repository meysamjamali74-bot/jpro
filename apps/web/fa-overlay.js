(()=>{
const map={
'DRAFT':'پیش‌نویس','PREPARED':'آماده بررسی','CHECKED':'بررسی‌شده','APPROVED':'تأییدشده','POSTED':'ثبت قطعی','LOCKED':'قفل‌شده','VOID':'باطل‌شده','WAITING_APPROVAL':'در انتظار تأیید','RESERVED':'رزرو کامل','PARTIAL_RESERVED':'رزرو ناقص','PICKING':'در حال جمع‌آوری','PACKING':'در حال بسته‌بندی','READY_TO_SHIP':'آماده ارسال','DISPATCHED':'ارسال‌شده','IN_ROUTE':'در مسیر','DELIVERED':'تحویل‌شده','PARTIAL_DELIVERY':'تحویل ناقص','PARTIAL_DELIVERED':'تحویل ناقص','OUTSTANDING':'تسویه‌نشده','OVERDUE':'سررسید گذشته','PAID':'تسویه‌شده','CANCELLED':'لغوشده','RETURNED':'برگشت‌شده','CREDIT_HOLD':'توقف اعتباری','READY':'آماده','CLOSED':'بسته‌شده','NEW':'جدید','ASSIGNED':'ارجاع‌شده','IN_PROGRESS':'در حال انجام','WAITING':'در انتظار','COMPLETED':'انجام‌شده','PLANNING':'برنامه‌ریزی','LOADING':'بارگیری','GATE_CHECK':'کنترل خروج','PARTIAL':'ناقص','FAILED':'ناموفق','SETTLEMENT_PENDING':'در انتظار تسویه','RECEIVED':'دریافت‌شده','QC':'کنترل کیفیت','PUTAWAY':'جانمایی‌شده','PENDING':'در انتظار','REJECTED':'ردشده','ACCEPTED':'پذیرفته‌شده','MATCH_PENDING':'در انتظار تطبیق','MATCH_EXCEPTION':'دارای مغایرت تطبیق','ACTIVE':'فعال','ON_LEAVE':'مرخصی','SUSPENDED':'تعلیق','TERMINATED':'خاتمه‌یافته','EXPIRED':'منقضی','CALCULATED':'محاسبه‌شده','REVIEWED':'بازبینی‌شده','CLAWED_BACK':'برگشت پورسانت','OPEN':'باز','ACKNOWLEDGED':'بررسی‌شده','RESOLVED':'رفع‌شده','IGNORED':'نادیده‌گرفته‌شده','NOT_REQUIRED':'نیاز ندارد','QUEUED':'در صف ارسال','SENT':'ارسال‌شده',
'OFFICIAL':'رسمی / مالیاتی','NON_OFFICIAL':'غیررسمی / داخلی','TYPE_1':'صورتحساب نوع اول','TYPE_2':'صورتحساب نوع دوم','TYPE_3':'صورتحساب نوع سوم','NON_ELECTRONIC':'غیرالکترونیکی','ORIGINAL':'اصلی','AMENDMENT':'اصلاحی','CANCELLATION':'ابطالی','RETURN':'برگشت / برگشت از فروش',
'CASH':'نقد','CREDIT':'بستانکار','MIXED':'ترکیبی','BANK':'بانک','POS':'کارتخوان','CHEQUE':'چک','TRANSFER':'حواله بانکی','PETTY_CASH':'تنخواه','OFFSET':'تهاتر',
'RECEIVABLE':'دریافتی','PAYABLE':'پرداختی','IN_SAFE':'در صندوق','DEPOSITED':'واگذار به بانک','COLLECTED':'وصول‌شده','BOUNCED':'برگشتی','ENDORSED':'واگذار به غیر','ISSUED':'صادرشده','CLEARED':'پاس‌شده',
'LEGAL':'حقوقی','NATURAL':'حقیقی','CUSTOMER':'مشتری','SUPPLIER':'تأمین‌کننده','EMPLOYEE':'کارمند','SALESPERSON':'فروشنده','DRIVER':'راننده','CONTRACTOR':'پیمانکار','AGENT':'نماینده',
'GOODS':'کالا','SERVICE':'خدمت','EXPENSE':'هزینه','ASSET':'دارایی','STANDARD':'مشمول ارزش افزوده','EXEMPT':'معاف از ارزش افزوده','ZERO':'نرخ صفر','SPECIAL':'نرخ خاص',
'DEBIT':'بدهکار','LIABILITY':'بدهی','EQUITY':'حقوق مالکانه','REVENUE':'درآمد','OTHER':'سایر','GENERAL':'عمومی','COLD':'سردخانه','FROZEN':'منجمد','QUARANTINE':'قرنطینه','TRANSIT':'در راه',
'RECEIPT':'ورود کالا','ISSUE':'خروج کالا','TRANSFER_IN':'انتقال ورودی','TRANSFER_OUT':'انتقال خروجی','RETURN_IN':'برگشت ورودی','RETURN_OUT':'برگشت خروجی','ADJUSTMENT_IN':'تعدیل افزایشی','ADJUSTMENT_OUT':'تعدیل کاهشی','COUNT':'انبارگردانی',
'VAT':'مالیات بر ارزش افزوده','DUTY':'عوارض','WITHHOLDING':'مالیات تکلیفی','GROSS_SALES':'فروش ناخالص','NET_SALES':'فروش خالص','GROSS_PROFIT':'سود ناخالص','COLLECTION':'وصول','TARGET':'هدف',
'LOW':'کم','NORMAL':'عادی','HIGH':'بالا','URGENT':'فوری','CRITICAL':'بحرانی','INFO':'اطلاع','WARNING':'هشدار',
'PERMANENT':'دائم','FIXED_TERM':'مدت معین','PROBATION':'آزمایشی','PART_TIME':'پاره‌وقت','HOURLY':'ساعتی','MALE':'مرد','FEMALE':'زن','SINGLE':'مجرد','MARRIED':'متأهل',
'EARNING':'مزایای پرداختی','DEDUCTION':'کسور','EMPLOYER_COST':'هزینه سهم کارفرما','LOAN':'وام','ADVANCE':'مساعده','FORMULA':'فرمول','PERCENT':'درصدی','DAILY':'روزانه','MONTHLY':'ماهانه',
'SALES_ORDER':'سفارش فروش','PURCHASE_ORDER':'سفارش خرید','SALES_INVOICE':'فاکتور فروش','SALES_INVOICE_IR':'فاکتور فروش','PURCHASE_INVOICE_IR':'فاکتور خرید','GOODS_RECEIPT':'رسید انبار','GOODS_RECEIPT_IR':'رسید انبار','TRIP':'سفر پخش','PRODUCT':'کالا / خدمت','PARTY':'شخص / شرکت','PAYROLL_BATCH':'دوره حقوق و دستمزد',
'PRICE':'قیمت','QUANTITY':'مقدار','TAX':'مالیات','ITEM':'قلم کالا','NO_PO':'فاقد سفارش خرید','NO_RECEIPT':'فاقد رسید انبار','UNMATCHED':'تطبیق‌نشده','SUGGESTED':'تطبیق پیشنهادی','MATCHED':'تطبیق‌شده'
};
const exact=/^[A-Z][A-Z0-9_]*$/;
function tableHeader(el){
 if(el.tagName!=='TD')return'';
 const row=el.parentElement,table=el.closest('table');if(!row||!table)return'';
 const index=[...row.children].indexOf(el);return (table.querySelectorAll('thead th')[index]?.textContent||'').trim();
}
function contextual(el,s){
 const header=tableHeader(el);
 if(s==='CREDIT'&&(header.includes('تسویه')||header.includes('روش پرداخت')||header.includes('نوع پرداخت')))return'نسیه / اعتباری';
 if(s==='CREDIT'&&(header.includes('ماهیت')||header.includes('حساب')))return'بستانکار';
 if(s==='PAYABLE'&&header.includes('چک'))return'پرداختی';
 if(s==='RECEIVABLE'&&header.includes('چک'))return'دریافتی';
 return map[s];
}
function translate(root=document){
 root.querySelectorAll('td,.badge,.status-chip b,.status-chip small,option').forEach(el=>{
   const s=(el.textContent||'').trim(),value=contextual(el,s);
   if(value)el.textContent=value;
   else if(exact.test(s)&&s.includes('_'))el.textContent=s.split('_').map(x=>map[x]||x).join(' ');
 });
}
let scheduled=false;const obs=new MutationObserver(()=>{if(scheduled)return;scheduled=true;requestAnimationFrame(()=>{scheduled=false;translate()})});obs.observe(document.documentElement,{childList:true,subtree:true,characterData:false});translate();
load('/phase17-ui.js');})();