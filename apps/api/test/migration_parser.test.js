import test from 'node:test';
import assert from 'node:assert/strict';
import { parseSqlScript,normalizeMigrationSql } from '../src/db.js';

test('migration parser keeps procedure body intact with DELIMITER',()=>{
 const sql=`CREATE TABLE x(id INT);\nDELIMITER $$\nCREATE PROCEDURE p()\nBEGIN\n  SELECT 1;\n  SELECT 2;\nEND$$\nDELIMITER ;\nINSERT INTO x VALUES (1);\n`;
 const s=parseSqlScript(sql);
 assert.equal(s.length,3);
 assert.match(s[0],/^CREATE TABLE/);
 assert.match(s[1],/CREATE PROCEDURE p\(\)[\s\S]*SELECT 1;[\s\S]*SELECT 2;[\s\S]*END$/);
 assert.match(s[2],/^INSERT INTO x/);
});

test('legacy phase15 migration references the real trips table',()=>{
 const sql=`CREATE TABLE sales_fulfillments(distribution_trip_id BIGINT,CONSTRAINT fk_sf_trip FOREIGN KEY(distribution_trip_id) REFERENCES distribution_trips(id));`;
 const normalized=normalizeMigrationSql('028_platform_phase15.sql',sql);
 assert.match(normalized,/REFERENCES trips\(id\)/);
 assert.doesNotMatch(normalized,/REFERENCES distribution_trips\(id\)/);
});
