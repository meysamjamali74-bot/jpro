# ترازپاد ERP

**Tarazpad ERP** یک ERP فارسی، RTL و فرآیندمحور برای حسابداری، فروش، خرید، CRM، انبار، لجستیک، منابع انسانی، مالیات و اتوماسیون است.

> وضعیت فعلی: **Enterprise 1.1 checkpoint** تکمیل و از Release Gate عبور کرده است. دامنه Enterprise 1.2 برای خزانه‌داری، تطبیق بانک/POS، پخش/POD و پورسانت در برنامه توسعه بعدی قرار دارد.

## امکانات فعال
- MySQL 8.4 / InnoDB و Migration خودکار
- JWT، نقش‌ها، Audit Trail و Unified Party
- حسابداری، دفتر کل، تراز آزمایشی و Posting عملیاتی
- فروش، خرید/AP، تطبیق سه‌طرفه و GRNI
- کنترل‌های مالیات و صورتحساب ایران، VAT و طبقه‌بندی رسمی/غیررسمی
- کالا، موجودی، انبار و زیرساخت عملیات سازمانی
- پرونده اشخاص، پرسنل، قرارداد، کارکرد، وام، حقوق و ثبت حسابداری حقوق
- Task، Route/Vehicle/Trip data model
- موتور پورسانت و زیرساخت فرآیندهای وصول
- داشبورد Drag & Drop با Widget Library و ذخیره چیدمان
- تم شیشه‌ای قابل ویرایش: فونت، اندازه، رنگ منو، Accent، Blur، Transparency و Background
- رابط فارسی RTL و فیلتر/صفحه‌بندی سمت سرور در ماژول‌های توسعه‌یافته
- Windows Electron Client و Native Windows Web Server Installer
- CI با MySQL واقعی، تست‌های End-to-End و Release Gate نصب ویندوز

## اجرای وب
`.env.example` را به `.env` کپی کنید و برای تمام Secretها مقدار واقعی و قوی قرار دهید. `docker-compose.yml` عمداً برای رمزهای Production مقدار پیش‌فرض ناامن ندارد و در صورت نبود Secretهای لازم اجرا متوقف می‌شود.

```bash
docker compose up -d --build
```

آدرس پیش‌فرض Docker: `http://localhost:8080`

## نسخه ویندوز
Installer بومی Windows، API + Web + Node runtime + MySQL 8.4 موردنیاز + Visual C++ Runtime را به‌صورت خودکار مدیریت می‌کند. اگر MySQL 8.4 سازگار یا پیش‌نیاز مناسب از قبل وجود داشته باشد از نصب تکراری اجتناب می‌شود. داده‌ها، تنظیمات و Backupها هنگام Uninstall عمداً حفظ می‌شوند.

نسخه Hardening فعلی Installer: **0.2.1**. نصب‌کننده در صورت اشغال بودن پورت 8080 یک پورت آزاد را انتخاب و همان پورت را در نصب/اجرای مجدد حفظ می‌کند.

## Enterprise 1.2
تمرکز برنامه بعدی روی Treasury، Bank/POS Reconciliation، Payment Proposal/Cash Forecast، چرخه کامل Distribution/POD/Settlement، Cold-chain Events و Commission مبتنی بر وصول واقعی است. جزئیات در `docs/PHASE-1-2-PLAN.md` ثبت شده است.

هیچ ماژولی صرفاً به‌دلیل وجود UI یا جدول دیتابیس Production Ready اعلام نمی‌شود؛ معیار پذیرش شامل Database، API، UI، Workflow، Accounting Integration، Permission، Audit، Reporting و Test است.
