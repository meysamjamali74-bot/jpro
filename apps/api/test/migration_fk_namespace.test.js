import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseSqlScript } from '../src/db.js';
const here=path.dirname(fileURLToPath(import.meta.url)),dbDir=path.resolve(here,'../../../database');

test('foreign-key constraint names remain unique across ordered migrations',()=>{
  const active=new Map();
  const files=fs.readdirSync(dbDir).filter(x=>/^\d+_.*\.sql$/.test(x)).sort();
  for(const file of files){
    const statements=parseSqlScript(fs.readFileSync(path.join(dbDir,file),'utf8'));
    for(const sql of statements){
      for(const m of sql.matchAll(/DROP\s+FOREIGN\s+KEY\s+`?([A-Za-z0-9_]+)`?/gi))active.delete(m[1].toLowerCase());
      for(const m of sql.matchAll(/CONSTRAINT\s+`?([A-Za-z0-9_]+)`?\s+FOREIGN\s+KEY/gi)){
        const key=m[1].toLowerCase(),prior=active.get(key);
        assert.equal(prior,undefined,`duplicate FK constraint ${m[1]} in ${file}; already active from ${prior}`);
        active.set(key,file);
      }
    }
  }
  assert.ok(active.size>0);
});
