# JPro ERP Cloud

JPro ERP برای استفاده چندکاربره تحت‌وب با GitHub + Supabase.

## نسخه زنده

- Host اصلی: Supabase Edge Function `jpro-app`
- URL: `https://klbrajeljnqdjburxrto.supabase.co/functions/v1/jpro-app/`
- Health: `https://klbrajeljnqdjburxrto.supabase.co/functions/v1/jpro-app/health`
- Frontend فعال: `cloud-v3.js`
- مدیریت اعضا/نقش‌ها: `cloud-admin.js`

## معماری

- `index.html` — ورود، ساخت حساب، انتخاب شرکت و Join Code
- `legacy.html` — رابط Sanitized JPro ERP
- `cloud-v3.js` — Auth، Company Context، Sync اتمیک، Realtime و Storage
- `cloud-admin.js` — تأیید عضویت، نقش، واحد و فعال/غیرفعال‌سازی کاربران
- `config.js` — URL پروژه و Runtime Config Endpoint؛ هیچ Secret/API Key در Repo ذخیره نمی‌شود
- `.deploy-clean/` — payload پاک‌سازی‌شده رابط برای materialize کردن `legacy.html`
- `.deploy-edge/` — payload فشرده برای Edge Host

## Supabase

پروژه فعال: `amory-hair-salon` / `klbrajeljnqdjburxrto`

JPro به جداول و سرویس‌های زیر متصل است:

- `profiles`
- `companies`
- `units`
- `company_memberships`
- `join_requests`
- `erp_records`
- `attachments`
- `audit_events`
- Private Storage bucket: `jpro-private`
- Realtime روی `erp_records`

RLS برای جداول JPro فعال است. جداول قدیمی Amory نیز قفل شده‌اند و دسترسی API ناشناس/کاربر عادی به آنها قطع شده، ولی داده‌ها حذف نشده‌اند.

## ورود و عضویت

1. کاربر اول با Email/Password حساب می‌سازد.
2. شرکت اول را می‌سازد و Admin می‌شود.
3. کد عضویت شرکت در Cloud > کاربران قابل مشاهده است.
4. سایر کاربران حساب می‌سازند و Join Code را وارد می‌کنند.
5. Admin از Cloud > کاربران درخواست را تأیید و Role/Unit تعیین می‌کند.

نقش‌ها شامل Admin، مدیرعامل، مالی، حسابدار، خزانه‌دار، صندوقدار، مدیر فروش، فروشنده، انباردار، لجستیک، منابع انسانی، حسابرس و متقاضی است.

## امنیت

- Service Role / Database Password / JWT Secret در Frontend یا GitHub وجود ندارد.
- Publishable Key در زمان اجرا از Edge Function عمومی Config دریافت می‌شود.
- دسترسی داده بر اساس Auth + Membership + RLS انجام می‌شود.
- Auditor برای داده‌های ERP Read-only است.
- ضمائم در Storage خصوصی و مسیر شرکت نگهداری می‌شوند.
- امضای Cloud با Re-authentication رمز حساب تأیید می‌شود.
- Audit Trail برای تغییرات عضویت و عملیات حساس ثبت می‌شود.

## Sync

نسخه فعلی رابط JPro را حفظ می‌کند و داده‌های ERP را به Postgres همگام می‌کند. حذف رکوردها به صورت Tombstone/atomic sync مدیریت می‌شود و Realtime تغییرات سایر کاربران را به مرورگرها می‌رساند.

مرحله بعدی Production، نرمال‌سازی کامل ماژول‌های حساس به جداول تخصصی است: دفترکل و سطر سند، فاکتور و خطوط، پرداخت و چک، انبار/Batch، Workflow و Posting حسابداری.

## نسخه نصبی آینده

همین Frontend بعداً می‌تواند داخل Electron یا Tauri بسته‌بندی شود و به همین Supabase/Postgres متصل بماند.

## یادداشت امنیت GitHub

نسخه فعلی شاخه `main` بدون Seed عملیاتی منتشر می‌شود. اگر Repo در گذشته Public بوده، برای حذف کامل داده‌های احتمالی از تاریخچه Git، Repository باید Private شود یا History با ابزار مدیریتی GitHub بازنویسی شود.
