# Tarazpad Enterprise 1.8 Release Candidate

Release branch: `enterprise-phase-1-8-release`

This branch is the single delivery path for the Enterprise 1.8 automatic Windows web-server installer.

## Included

- Iranian accounting/tax invoice controls and official/non-official invoices
- Chart of accounts, parties, products/services, HR and payroll
- Treasury, bank reconciliation, POS, checks, AR/AP and payment workflows
- Procurement, inventory/WMS, FEFO allocation and backend transactional FIFO costing
- Distribution/logistics, POD, trip settlement and commission engine
- CRM, loyalty, BPM, DMS and office automation
- BI/dashboard builder, multi-currency, consolidation and security controls
- Financial reporting, fiscal close/year-end and Iran compliance center
- Enterprise 1.8 detailed master data, visual price lists, professional invoice/waybill printing and detailed company bank master
- Automatic prerequisite-aware Windows installer

## Release gates

The release may be merged and packaged only when all applicable gates pass on the same commit:

1. Syntax/unit tests
2. Fresh MySQL 8.4 migration/startup
3. Finance/accounting E2E and journal balancing
4. Procurement/inventory/WMS/FIFO/FEFO E2E
5. Treasury/payroll/CRM/ERP diagnostic E2E
6. Enterprise 1.8 detail/printing gate
7. Web release build
8. Native Windows automatic installer build and reinstall/idempotency validation

No failed gate is waived for the final installer.
