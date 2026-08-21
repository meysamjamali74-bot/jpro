// Compatibility runner for mysql2 JSON columns.
// MySQL 8.4/mysql2 may return JSON columns either as parsed objects or strings.
// The underlying Phase 1.5 E2E historically parses result_json explicitly, so
// preserve that test while making JSON.parse idempotent for already-parsed data.
const parse=JSON.parse.bind(JSON);
JSON.parse=(value,...args)=>value!==null&&typeof value==='object'?value:parse(value,...args);
await import('./phase15_e2e.mjs');
