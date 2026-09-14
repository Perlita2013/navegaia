import test from 'node:test';
import assert from 'node:assert/strict';
import {demurrage,chileDay} from '../lib/domain';
test('antes de ETA no existe demurrage',()=>assert.deepEqual(demurrage('2026-09-20',7,'2026-09-14'),{days:0,overdue:0,remaining:13,arrived:false}));
test('día de llegada y límite exacto de días libres',()=>{assert.equal(demurrage('2026-09-01',7,'2026-09-01').overdue,0);assert.equal(demurrage('2026-09-01',7,'2026-09-08').overdue,0);assert.equal(demurrage('2026-09-01',7,'2026-09-09').overdue,1)});
test('DST chileno no agrega ni elimina días calendario',()=>assert.equal(demurrage('2026-09-05',1,'2026-09-07').overdue,1));
test('año bisiesto y cruce de mes',()=>assert.equal(demurrage('2024-02-28',1,'2024-03-01').overdue,1));
test('rechaza fechas inexistentes y días libres inválidos',()=>{assert.throws(()=>demurrage('2026-02-30',7));assert.throws(()=>demurrage('2026-09-01',-1));assert.throws(()=>demurrage('x',1));assert.throws(()=>demurrage('2026-09-01',1.5))});
test('fecha operativa en Santiago al cruzar medianoche UTC',()=>assert.equal(chileDay(new Date('2026-07-02T02:00:00Z')),'2026-07-01'));
