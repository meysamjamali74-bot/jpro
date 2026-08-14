# JPro ERP Cloud Pilot

نسخه گذار JPro ERP v3.3 برای استفاده تحت‌وب با GitHub + Supabase.

## معماری فعلی

- `index.html` — ورود ابری و Cloud Shell بدون به‌هم‌زدن چیدمان ERP
- `legacy.html` — رابط کامل JPro ERP v3.3
- `cloud.js` — Supabase Auth، Company Context، Sync و Realtime
- `config.js` — Project URL و **Publishable Key** (نه Service Role)
- `supabase/migrations/0001_jpro_cloud_core.sql` — دیتابیس و RLS
- `.github/workflows/pages.yml` — آماده GitHub Pages

## امنیت

- Service Role یا Secret Key نباید در Frontend یا GitHub قرار بگیرد.
- Frontend فقط از Supabase Publishable Key استفاده می‌کند.
- تمام جداول Public دارای RLS هستند.
- دسترسی داده بر اساس عضویت در شرکت محدود می‌شود.
- Auditor در پایگاه داده Read-only است.
- امضای Cloud در Pilot با ورود مجدد رمز حساب Supabase تأیید می‌شود.

## راه‌اندازی

1. پروژه Supabase مخصوص JPro را به اتصال ChatGPT/Supabase متصل یا Refresh کنید.
2. Migration را روی پروژه اعمال کنید.
3. Project URL و Publishable Key را در `config.js` قرار دهید.
4. GitHub Pages را از Workflow موجود منتشر کنید.
5. کاربر اول با Email/Password وارد می‌شود، شرکت اول را می‌سازد و نقش admin می‌گیرد.

## مسیر Production

Cloud Pilot رابط فعلی را نگه می‌دارد و داده‌های LocalStorage را به Supabase Sync می‌کند. ماژول‌های حساس حسابداری به‌تدریج باید به جداول تخصصی Postgres منتقل شوند: دفتر کل، فروش/فاکتور، خزانه و چک، انبار و Batch، Workflow و Audit Trail.

## نسخه نصبی آینده

همین Frontend بعداً می‌تواند داخل Electron یا Tauri بسته‌بندی شود و همچنان به Supabase/Postgres متصل بماند.

## چیدمان Cloud

Cloud Shell هیچ Header یا فضای اضافه‌ای به ERP تحمیل نمی‌کند؛ رابط اصلی تمام viewport را در اختیار دارد و کنترل Cloud فقط شناور است.
