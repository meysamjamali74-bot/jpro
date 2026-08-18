# Tarazpad ERP Web Release Validation

This file records the release gate for the tested web build.

Required gates:
- MySQL 8.4 service health
- API health and authentication
- Unauthorized access rejection
- Invalid login rejection
- Party and product creation
- Sales invoice creation and posting
- Double-entry balance check
- Dashboard summary and layout persistence
- User preference persistence
- API restart with data retained in MySQL
- Static web asset and brand checks
- Security header smoke check
- Docker image build
- Unit tests and syntax checks

Passing these gates validates the currently implemented web foundation. It does not certify unimplemented Enterprise 1.0 modules.
