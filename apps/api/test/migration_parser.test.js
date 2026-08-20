import test from 'node:test';
import assert from 'node:assert/strict';
import { parseSqlScript } from '../src/db.js';

test('migration parser keeps procedure body intact with DELIMITER',()=>{
 const sql=`CREATE TABLE x(id INT);\nDELIMITER $$\nCREATE PROCEDURE p()\nBEGIN\n  SELECT 1;\n  SELECT 2;\nEND$$\nDELIMITER ;\nINSERT INTO x VALUES (1);\n`;
 const s=parseSqlScript(sql);
 assert.equal(s.length,3);
 assert.match(s[0],/^CREATE TABLE/);
 assert.match(s[1],/CREATE PROCEDURE p\(\)[\s\S]*SELECT 1;[\s\S]*SELECT 2;[\s\S]*END$/);
 assert.match(s[2],/^INSERT INTO x/);
});
