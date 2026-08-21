# Tarazpad ERP — Audit & Gap Matrix — 2026-08-21

## Scope
Audit of the existing `jpro` repository. The project is hardened in place; it is not rebuilt from scratch.

## Current-state summary
- MySQL 8.4/InnoDB migrations and a production API exist.
- Persian RTL web UI and Windows packaging pipelines exist.
- Enterprise 1.1 release gate previously passed CI, strict gate, web release and native Windows installer tests.
- Enterprise 1.2 is currently a planned scope, not a completed release.

## Gap Matrix

| Priority | Area | Gap | Risk | Action | Status |
|---|---|---|---|---|---|
| Critical | Authentication | Production JWT could fall back to a known development secret when `JWT_SECRET` was absent | Token forgery / auth compromise | Fail closed in production; require >=48 chars; constrain issuer/audience/HS256 | FIXED on release branch |
| Critical | Release delivery | No verified installer artifact was attached to the current hardening checkpoint | User cannot safely install the audited build | Re-run Windows installer gate and export verified Setup + SHA256 | IN PROGRESS |
| High | Supply chain | Runtime dependencies used floating caret ranges | Non-reproducible builds / unexpected transitive changes | Pin direct runtime versions; keep installer build gate | FIXED on release branch |
| High | Installer | Web port is fixed at 8080 in the native install script | Install can fail on machines already using 8080 | Select/reuse a free persisted web port | IN PROGRESS |
| High | Installer security | Initial admin credential file requires explicit ACL hardening | Local credential exposure to non-admin users | Restrict to SYSTEM + Administrators | IN PROGRESS |
| High | HTTP security | Production CORS is broadly permissive and CSP is disabled | Increased browser attack surface | Restrict same-origin/allowlist; enable a tested CSP | NEXT |
| High | Authentication | No explicit login throttling in the API | Brute-force exposure | Add bounded login rate limiting and tests | NEXT |
| Medium | Release metadata | README/release version text lags implemented Enterprise 1.1 state | Operator confusion | Refresh after release gate | NEXT |
| Medium | Dependency lock | No committed npm lockfile is visible in the API package | Transitive dependency drift | Generate and commit lockfile in dependency-maintenance pass | NEXT |
| Medium | Enterprise scope | Treasury/reconciliation/POD/commission 1.2 is planned, not yet accepted | Feature incompleteness vs master roadmap | Implement after release hardening | DEFERRED |

## Release gate for this hardening pass
1. Syntax/static checks.
2. API tests.
3. MySQL-backed migration/E2E checks from existing workflows.
4. Native Windows first-install health test.
5. Second-run/idempotency test.
6. Produce Setup EXE and SHA256 manifest.

## Decision
The existing repository is technically salvageable and should be evolved in place. A rewrite would add migration and regression risk without evidence that the current architecture is unrecoverable.
