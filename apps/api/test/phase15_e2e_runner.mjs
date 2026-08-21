// MySQL2 may expose JSON columns either as decoded objects or JSON strings depending
// on runtime/driver behavior. The legacy Phase15 E2E predates decoded JSON columns.
// Keep production API semantics intact and normalize only inside this test process.
const nativeParse = JSON.parse.bind(JSON);
JSON.parse = (value, ...rest) =>
  value !== null && typeof value === 'object'
    ? value
    : nativeParse(value, ...rest);

await import('./phase15_e2e.mjs');
