# Tarazpad Enterprise 1.8 — Audit & Gap Matrix — 2026-08-21

## Audit basis
Delivery branch audited: `enterprise-phase-1-8-release` (PR #18), not stale `main`.
Final hardening branch: `release/tarazpad-enterprise-1-8-final-20260821`.

## Gap Matrix

| Priority | Area | Observed gap | Release risk | Remediation | Status |
|---|---|---|---|---|---|
| Critical | Fresh MySQL migration | Phase 1.5 legacy FK can reference nonexistent `distribution_trips` instead of real `trips` | Clean install/migration may fail | Normalize legacy migration at runtime and regression-test it | FIXED |
| Critical | Authentication | JWT could fall back to known `dev-only-change-me` in production | Token forgery / unauthorized access | Production fails closed unless JWT secret is >=48 chars; issuer/audience/HS256 constrained | FIXED |
| Critical | Docker secrets | Known fallback DB/root/JWT/admin credentials were accepted | Predictable production credentials | Require explicit production secrets; remove insecure fallbacks | FIXED |
| Critical | Release targeting | `main` is older than current Enterprise 1.8 delivery line | Shipping stale/incomplete ERP | Build only from Enterprise 1.8 release lineage | FIXED |
| High | Installer accounting controls | HARD_CLOSED DB guards existed but packaged test did not assert their presence | Close-period immutability could regress unnoticed | Installer CI now verifies required database triggers after packaged setup | FIXED / GATE PENDING |
| High | Installer credentials | Initial-login file is sensitive | Local credential disclosure | Existing ACL restriction retained; CI now asserts protected ACL and SYSTEM/Administrators-only access | FIXED / GATE PENDING |
| High | Supply chain | Direct API dependency versions used caret ranges | Direct dependency drift between builds | Pin direct production dependency versions | FIXED |
| High | Installer port | Native installer assumes web port 8080 | Install may fail if 8080 is occupied | Dynamic persisted web-port selection | OPEN — does not block normal clean-machine release, should be next installer hardening item |
| High | HTTP security | CORS is broad and CSP is disabled in current API bootstrap | Browser attack surface | Same-origin/allowlist CORS + tested CSP | OPEN — next security hardening pass |
| High | Authentication | No explicit login rate limiting observed | Brute-force exposure | Add bounded login throttling with audit events | OPEN — next security hardening pass |
| Medium | Lockfile | API production build does not yet enforce a committed lockfile | Transitive dependency drift | Generate/commit lockfile and switch release build to `npm ci` | OPEN |

## Release gate — installer delivery
The Enterprise 1.8 installer is deliverable only when the same commit passes:
1. Syntax and unit tests.
2. Fresh MySQL 8.4 migration/startup.
3. Finance/accounting and journal-balance E2E.
4. Procurement/inventory/WMS/FIFO/FEFO E2E.
5. Treasury/payroll/CRM/ERP diagnostic E2E.
6. Enterprise 1.8 detail/printing gate.
7. Web release build.
8. Native Windows installer build, first run, protected initial credentials, database-guard verification, second-run idempotency and health check.
9. SHA-256 manifest generation for the exact Setup EXE.

## Decision
No rewrite. The existing Enterprise 1.8 architecture is retained and hardened in place. Critical release defects are corrected before packaging; remaining High/Medium gaps are explicitly tracked rather than hidden.
