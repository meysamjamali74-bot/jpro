# ترازپاد ERP

**Tarazpad ERP** هسته یک ERP فارسی، RTL و فرآیندمحور برای حسابداری، فروش، CRM، انبار، لجستیک و اتوماسیون است.

> وضعیت فعلی: **Foundation Release 0.1**. هسته فنی و چند فرآیند واقعی پیاده‌سازی شده‌اند؛ این ریلیز هنوز Enterprise 1.0 نهایی نیست.

## امکانات فعال
- MySQL 8.4 / InnoDB و Migration خودکار
- JWT، نقش‌ها، Audit Trail و Unified Party پایه
- کالا، موجودی، فاکتور فروش و Posting واقعی به دفتر کل
- Trial Balance، Task، Route/Vehicle/Trip data model
- موتور پورسانت با وصول، برگشت و Tier
- داشبورد Drag & Drop با Widget Library و ذخیره چیدمان
- تم شیشه‌ای قابل ویرایش: فونت، اندازه، رنگ منو، Accent، Blur، Transparency و Background
- رابط فارسی RTL
- Windows Electron Client + NSIS Setup pipeline
- CI با MySQL واقعی و تست End-to-End پایه

## اجرای وب
`.env.example` را به `.env` کپی و تمام Secretهای نمونه را تغییر دهید، سپس:
```bash
docker compose up -d --build
```
آدرس: `http://localhost:8080`

## نسخه ویندوز
`apps/desktop` Client ویندوزی متصل به Web Server است و GitHub Actions فایل Setup.exe می‌سازد. Installer کامل Local Server/MySQL در فاز بعدی ساخته می‌شود.

## مسیر Enterprise 1.0
Accounting/Treasury کامل، AR/AP، WMS، DMS/POD/Settlement، Procurement/3-Way Match/GRNI، CRM 360، HR/Payroll، BPMS، Loyalty، BI Semantic Layer، Reconciliation/Exception/Backup Center، Mobile/Offline و Installer کامل Server/Client.

هیچ ماژولی تا تکمیل Database، API، UI، Workflow، Accounting Integration، Permission، Audit، Reporting و Test، Production Ready اعلام نمی‌شود.
