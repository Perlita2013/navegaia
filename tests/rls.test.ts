import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';

test('RLS en PostgreSQL real embebido: aislamiento, roles, MFA, Storage y auditoría',async t=>{
 const db=new PGlite();
 await db.exec(`create role anon; create role authenticated; create role service_role;
 create schema auth; create schema storage;
 create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz);
 create function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
 create function auth.uid() returns uuid language sql stable as $$ select (auth.jwt()->>'sub')::uuid $$;
 grant usage on schema auth,storage,public to authenticated,anon,service_role;
 grant execute on all functions in schema auth to authenticated,anon,service_role;
 create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
 create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text);
 alter table storage.objects enable row level security;
 grant select,insert,delete on storage.objects to authenticated;
 `);
 await db.exec(await readFile(new URL('../supabase/migrations/001_core.sql',import.meta.url),'utf8'));
 await db.exec(await readFile(new URL('../supabase/migrations/002_jobs.sql',import.meta.url),'utf8'));
 await db.exec(await readFile(new URL('../supabase/migrations/003_commercial.sql',import.meta.url),'utf8'));
 const A='10000000-0000-4000-8000-000000000001',B='10000000-0000-4000-8000-000000000002';
 const ownerA='20000000-0000-4000-8000-000000000001',ownerB='20000000-0000-4000-8000-000000000002',importerA='20000000-0000-4000-8000-000000000003',importerB='20000000-0000-4000-8000-000000000004',execA='20000000-0000-4000-8000-000000000005',newUser='20000000-0000-4000-8000-000000000006';
 const sA='30000000-0000-4000-8000-000000000001',sB='30000000-0000-4000-8000-000000000002',sOther='30000000-0000-4000-8000-000000000003';
 const dA='40000000-0000-4000-8000-000000000001',dHidden='40000000-0000-4000-8000-000000000002',dB='40000000-0000-4000-8000-000000000003';
 await db.exec(`insert into auth.users values ('${ownerA}','owner-a@example.test',now()),('${ownerB}','owner-b@example.test',now()),('${importerA}','importer-a@example.test',now()),('${importerB}','importer-b@example.test',now()),('${execA}','exec-a@example.test',now()),('${newUser}','new@example.test',now());
 insert into public.empresas(id,nombre) values('${A}','Agencia A'),('${B}','Agencia B');
 update public.empresas set limite_usuarios=5 where id='${A}';
 insert into public.usuarios(id,empresa_id,nombre,rol) values('${ownerA}','${A}','Owner A','owner'),('${ownerB}','${B}','Owner B','owner'),('${importerA}','${A}','Importador A','importador'),('${importerB}','${B}','Importador B','importador'),('${execA}','${A}','Ejecutivo A','ejecutivo');
 insert into public.embarques(id,empresa_id,referencia,bl,importador,importador_id,naviera,puerto,origen,eta) values('${sA}','${A}','A-1','BL-A','Cliente A','${importerA}','ONE','San Antonio','Busan','2026-09-01'),('${sB}','${B}','B-1','BL-B','Cliente B','${importerB}','MSC','Valparaíso','Busan','2026-09-01'),('${sOther}','${A}','A-2','BL-A2','Otro cliente',null,'ONE','San Antonio','Busan','2026-09-01');
 insert into public.documentos(id,empresa_id,embarque_id,nombre,ruta,tipo,visible_importador) values('${dA}','${A}','${sA}','A.pdf','${A}/${dA}.pdf','BL',true),('${dHidden}','${A}','${sA}','Interno.pdf','${A}/${dHidden}.pdf','BL',false),('${dB}','${B}','${sB}','B.pdf','${B}/${dB}.pdf','BL',true);
 insert into storage.objects(bucket_id,name) values('documentos','${A}/${dA}.pdf'),('documentos','${A}/${dHidden}.pdf'),('documentos','${B}/${dB}.pdf');`);
 async function as(id:string,aal='aal2'){await db.exec('reset role');await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:id,aal,role:'authenticated'})]);await db.exec('set role authenticated')}
 async function count(table:string){return Number((await db.query<{n:number}>(`select count(*)::integer n from ${table}`)).rows[0].n)}
 await t.test('owner A no puede leer ni cambiar la empresa B',async()=>{await as(ownerA);assert.equal(await count('public.empresas'),1);assert.equal(await count('public.embarques'),2);assert.equal((await db.query(`update public.embarques set estado='arribo' where id='${sB}' returning id`)).rows.length,0);await assert.rejects(db.exec(`insert into public.embarques(empresa_id,referencia,bl,importador,naviera,puerto,origen,eta) values('${B}','forged','x','x','x','x','x','2026-09-01')`));});
 await t.test('importador ve solo embarques asignados y documentos compartidos',async()=>{await as(importerA);assert.equal(await count('public.embarques'),1);assert.equal(await count('public.documentos'),1);assert.equal(await count('storage.objects'),1);assert.equal(await count('public.audit_log'),0);assert.equal((await db.query(`update public.embarques set estado='liberado' where id='${sA}' returning id`)).rows.length,0);await assert.rejects(db.exec(`insert into public.documentos(empresa_id,embarque_id,nombre,ruta,tipo) values('${A}','${sA}','x','fake','BL')`));});
 await t.test('sin segundo factor no hay acceso aun con JWT autenticado',async()=>{await as(ownerA,'aal1');for(const table of ['empresas','usuarios','embarques','documentos','eventos','audit_log','notificaciones','ai_usage'])assert.equal(await count('public.'+table),0,table);assert.equal(await count('storage.objects'),0);await assert.rejects(db.exec("select public.bootstrap_company('Intruso','Usuario')"));await as(ownerA,'');assert.equal(await count('public.embarques'),0)});
 await t.test('ningún cliente puede escalar rol, cambiar plan o forjar auditoría',async()=>{await as(execA);await assert.rejects(db.exec(`update public.usuarios set rol='owner' where id='${execA}'`));await assert.rejects(db.exec(`update public.empresas set plan='pro' where id='${A}'`));await assert.rejects(db.exec(`insert into public.audit_log(empresa_id,accion,tabla) values('${A}','falso','usuarios')`));await assert.rejects(db.exec(`delete from public.audit_log where empresa_id='${A}'`));await assert.rejects(db.exec("select public.add_member('new@example.test','gerente')"));await assert.rejects(db.exec('select public.claim_notifications()'));await assert.rejects(db.exec(`select public.apply_subscription('${A}','sub_falsa',true)`))});
 await t.test('owner solo añade miembros a su empresa; no reasigna identidades existentes',async()=>{await as(ownerA);await db.exec("select public.add_member('new@example.test','gerente')");assert.equal((await db.query<{empresa_id:string}>(`select empresa_id from public.usuarios where id='${newUser}'`)).rows[0].empresa_id,A);await assert.rejects(db.exec("select public.add_member('owner-b@example.test','gerente')"))});
 await t.test('bloquea vínculos y movimientos entre tenants',async()=>{await as(ownerA);await assert.rejects(db.exec(`update public.embarques set importador_id='${importerB}' where id='${sA}'`));await assert.rejects(db.exec(`update public.embarques set empresa_id='${B}' where id='${sA}'`));await assert.rejects(db.exec(`update public.documentos set embarque_id='${sB}' where id='${dA}'`));await assert.rejects(db.exec(`update public.documentos set ruta='${B}/${dA}.pdf' where id='${dA}'`));await assert.rejects(db.exec(`insert into storage.objects(bucket_id,name) values('documentos','${B}/forged.pdf')`))});
 await t.test('cambio permitido genera eventos y audit log sin inserts desde cliente',async()=>{await as(ownerA);const before=await count('public.audit_log');await db.exec(`update public.embarques set estado='arribo' where id='${sA}'`);assert.equal(await count('public.audit_log'),before+1);assert.equal((await db.query(`select id from public.eventos where embarque_id='${sA}' and accion like 'Estado actualizado%'`)).rows.length,1)});
 await t.test('todas las tablas públicas y storage.objects tienen RLS',async()=>{await db.exec('reset role');const r=await db.query<{relname:string;relrowsecurity:boolean}>("select c.relname,c.relrowsecurity from pg_class c join pg_namespace n on c.relnamespace=n.oid where n.nspname='public' and c.relkind='r'");assert.equal(r.rows.length,10);assert.ok(r.rows.every(x=>x.relrowsecurity))});

 await t.test('nadie se autoasigna Owner de plataforma ni consulta otros clientes',async()=>{
  for(const id of [ownerA,execA,importerA,newUser]){await as(id);assert.equal((await db.query<{ok:boolean}>('select public.platform_access() ok')).rows[0].ok,false);await assert.rejects(db.exec('select public.platform_overview()'));await assert.rejects(db.exec(`insert into public.platform_owners(user_id) values('${id}')`));await assert.rejects(db.exec(`select public.platform_update_company('${B}','crece','activo','2026-09-01')`));await assert.rejects(db.exec(`select private.usage_summary('${B}')`));assert.equal(await count('public.platform_audit'),0)}
 });
 const platform='20000000-0000-4000-8000-000000000099';
 await db.exec('reset role');await db.exec(`insert into auth.users values('${platform}','platform@example.test',now());insert into public.platform_owners(user_id) values('${platform}')`);
 await t.test('Owner comercial requiere MFA y no obtiene documentos de clientes',async()=>{
  await as(platform,'aal1');assert.equal(await count('public.platform_owners'),0);await assert.rejects(db.exec('select public.platform_overview()'));
  await as(platform);const result=(await db.query<{value:{clientes:{id:string;ejecutivos:number}[]}}>('select public.platform_overview() value')).rows[0].value;assert.equal(result.clientes.length,2);assert.equal(result.clientes.find(c=>c.id===A)?.ejecutivos,1);assert.equal(await count('public.embarques'),0);assert.equal(await count('public.documentos'),0);assert.equal(await count('storage.objects'),0);assert.equal(await count('public.platform_audit'),1);
  await db.exec(`select public.platform_update_company('${A}','crece','activo','2026-09-01')`);assert.equal(await count('public.platform_audit'),2);await assert.rejects(db.exec(`select public.platform_update_company('${A}','emprende','activo','2026-09-01')`));
  await as(ownerA);const u=(await db.query<{v:{plan:string;limite_usuarios:number}}>('select public.company_usage() v')).rows[0].v;assert.equal(u.plan,'crece');assert.equal(u.limite_usuarios,5);
 });
 await t.test('cupos por tenant impiden altas, fechas falsificadas y devolución al borrar',async()=>{
  await db.exec('reset role');await db.exec(`update public.empresas set limite_embarques=2,limite_documentos=2,limite_usuarios=3 where id='${A}'`);
  await as(execA);await assert.rejects(db.exec(`insert into public.embarques(empresa_id,referencia,bl,importador,naviera,puerto,origen,eta,created_at) values('${A}','exceso','x','x','x','x','x','2026-09-01','2000-01-01')`));
  await assert.rejects(db.exec(`insert into public.documentos(empresa_id,embarque_id,nombre,ruta,tipo) values('${A}','${sA}','extra.pdf','${A}/00000000-0000-4000-8000-000000000000.pdf','BL')`));
  await db.exec(`delete from public.documentos where id='${dHidden}'`);
  await as(ownerA);const u=(await db.query<{v:{documentos:number}}>('select public.company_usage() v')).rows[0].v;assert.equal(u.documentos,2);
  await db.exec(`update public.embarques set estado='presentado' where id='${sA}'`);
  await as(platform);await db.exec(`select public.platform_update_company('${B}','emprende','suspendido',null)`);
  await as(ownerB);assert.equal(await count('public.embarques'),1);await assert.rejects(db.exec(`insert into public.embarques(empresa_id,referencia,bl,importador,naviera,puerto,origen,eta) values('${B}','suspendido','x','x','x','x','x','2026-09-01')`));
 });
 await db.close();
});
