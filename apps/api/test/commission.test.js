import test from 'node:test';
import assert from 'node:assert/strict';
import { calculateCommission } from '../src/commission.js';
test('collection based commission uses collected amount',()=>{const r=calculateCommission({basisAmount:500000000,collectedAmount:300000000,rule:{collectionBased:true,baseRate:1}});assert.equal(r.eligibleBase,300000000);assert.equal(r.commission,3000000)});
test('returns reduce eligible commission and tier is applied',()=>{const r=calculateCommission({basisAmount:2200000000,returnedAmount:300000000,rule:{baseRate:1,tiers:[{threshold:1000000000,rate:1.5},{threshold:2000000000,rate:2}]}});assert.equal(r.eligibleBase,1900000000);assert.equal(r.rate,1.5);assert.equal(r.commission,28500000)});
