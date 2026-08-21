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
| Critical | Docker secrets | Production Compose supplied known fallback credentials for DB/root/JWT/admin | Predictable production credentials | Require explicit secrets via Compose interpolation; no insecure fallbacks | FIXED on release branch |
| Critical | Release delivery | No verified installer artifact was attached to the current hardening checkpoint | User cannot safely install the audited build | Re-run Windows installer gate and export verified Setup + SHA256 | IN PROGRESS |
| High | Supply chain | Runtime dependencies used floating caret ranges | Non-reproducible direct dependency selection | Pin direct runtime versions; keep installer build gate | FIXED on release branch |
| High | Installer | Web port was fixed at 8080 in the native install script | Install could fail on machines already using 8080 | Select/reuse a free persisted web port and test forced collision | FIXED; awaiting release gate |
| High | Installer security | Initial admin credential file needs restricted local access | Local credential exposure to non-admin users | Existing ACL protection confirmed; CI now asserts SYSTEM/Administrators only | VERIFIED IN SOURCE; awaiting gate |
| High | HTTP security | Production CORS is broadly permissive and CSP is disabled | Increased browser attack surface | Restrict same-origin/allowlist; enable a tested CSP | NEXT HARDENING PASS |
| High | Authentication | No explicit login throttling in the API | Brute-force exposure | Add bounded login rate limiting and tests | NEXT HARDENING PASS |
| Medium | Release metadata | README/release version text lags implemented Enterprise 1.1 state | Operator confusion | Refresh after release gate | NEXT |
| Medium | Dependency lock | No committed npm lockfile is visible in the API package | Transitive dependency drift | Generate and commit lockfile in dependency-maintenance pass | NEXT |
| Medium | Enterprise scope | Treasury/reconciliation/POD/commission 1.2 is planned, not yet accepted | Feature incompleteness vs master roadmap | Implement after release hardening | DEFERRED |

## Release gate for this hardening pass
1. Syntax/static checks.
2. API tests.
3. MySQL-backed migration/E2E checks from existing workflows.
4. Native Windows first-install health test, including forced port-8080 collision.
5. Initial-login ACL assertion.
6. Second-run/idempotency test.
7. Produce Setup EXE and SHA256 manifest.

## Decision
The existing repository is technically salvageable and should be evolved in place. A rewrite would add migration and regression risk without evidence that the current architecture is unrecoverable.
