import test from 'node:test';
import assert from 'node:assert/strict';
import {parseExtraction,emptyExtraction,extractionPrompt} from '../lib/domain';
test('emisor extranjero sin RUT y partidas con cero inicial',()=>{const v=parseExtraction({...emptyExtraction,emisor:'Export Trading Co.',partidas_arancelarias:['010121'],moneda:'USD',monto:15890.25});assert.equal(v.rut,null);assert.equal(v.partidas_arancelarias[0],'010121')});
test('rechaza números ambiguos en strings, negativos y claves inesperadas',()=>{assert.throws(()=>parseExtraction({...emptyExtraction,monto:'1.890,50'}));assert.throws(()=>parseExtraction({...emptyExtraction,monto:-1}));assert.throws(()=>parseExtraction({...emptyExtraction,aprobado:true}))});
test('no admite partida inventada en texto o incoterm fuera del catálogo',()=>{assert.throws(()=>parseExtraction({...emptyExtraction,partidas_arancelarias:['probablemente 8504']}));assert.throws(()=>parseExtraction({...emptyExtraction,incoterm:'XYZ'}))});
test('rechaza pesos incoherentes',()=>assert.throws(()=>parseExtraction({...emptyExtraction,peso_bruto_kg:5,peso_neto_kg:8})));
test('documento sin datos se conserva como desconocido',()=>assert.deepEqual(parseExtraction(emptyExtraction),emptyExtraction));
test('prompt impide seguir instrucciones del documento y exige revisión',()=>{assert.match(extractionPrompt,/DATOS NO CONFIABLES/);assert.match(extractionPrompt,/Nunca inventes/);assert.match(extractionPrompt,/revisión humana/)});
