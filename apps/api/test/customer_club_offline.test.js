import test from 'node:test';
import assert from 'node:assert/strict';
import { parseCsv, normalizeInputRow } from '../src/customer_club_offline.js';

test('customer club CSV parser accepts Persian headers and quoted fields',()=>{
 const csv='نام مشتری,موبایل,کد مشتری,موضوع پیگیری,توضیحات\n"شرکت نمونه","09120000000","C-01","تماس مجدد","تهران، شعبه مرکزی"';
 const rows=parseCsv(csv);
 assert.equal(rows.length,1);
 assert.equal(rows[0].name,'شرکت نمونه');
 assert.equal(rows[0].mobile,'09120000000');
 assert.equal(rows[0].code,'C-01');
 assert.equal(rows[0].nextActionTitle,'تماس مجدد');
 assert.equal(rows[0].notes,'تهران، شعبه مرکزی');
});

test('customer club CSV parser detects semicolon and tab delimiters',()=>{
 assert.equal(parseCsv('name;mobile\nAli;09121111111')[0].mobile,'09121111111');
 assert.equal(parseCsv('name\tmobile\nSara\t09122222222')[0].name,'Sara');
});

test('customer club normalization protects operational enum values',()=>{
 const r=normalizeInputRow({name:'Test',priority:'invalid',lifecycleStatus:'wrong',mobile:'0912 123-4567'},1);
 assert.equal(r.priority,'NORMAL');
 assert.equal(r.lifecycleStatus,'NEW');
 assert.equal(r.mobile,'09121234567');
});
