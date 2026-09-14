-- NavegaIA: one company per identity in MVP; owner is company-scoped.
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create table public.empresas(id uuid primary key default gen_random_uuid(),nombre text not null check(length(nombre) between 3 and 100),plan text not null default 'esencial' check(plan in ('esencial','pro')),stripe_subscription_id text unique,created_at timestamptz not null default now());
create table public.usuarios(id uuid primary key references auth.users(id),empresa_id uuid not null references public.empresas(id),nombre text not null,rol text not null check(rol in ('owner','gerente','ejecutivo','importador')),created_at timestamptz not null default now(),unique(empresa_id,id));
create table public.embarques(id uuid primary key default gen_random_uuid(),empresa_id uuid not null references public.empresas(id),referencia text not null,bl text not null,importador text not null,importador_id uuid,naviera text not null,puerto text not null,origen text not null,eta date not null,free_time integer not null default 7 check(free_time between 0 and 365),estado text not null default 'pre-arribo' check(estado in ('pre-arribo','arribo','presentado','selectivizado','liberado')),partida text not null default '' check(partida='' or partida ~ '^\d{4,10}$'),historial_incidentes integer not null default 0 check(historial_incidentes>=0),riesgo_puerto boolean not null default false,created_at timestamptz not null default now(),unique(empresa_id,id),unique(empresa_id,referencia),foreign key(empresa_id,importador_id) references public.usuarios(empresa_id,id));
create index on public.embarques(empresa_id,estado,eta);
create index on public.embarques(importador_id);
create table public.documentos(id uuid primary key default gen_random_uuid(),empresa_id uuid not null references public.empresas(id),embarque_id uuid not null,nombre text not null,ruta text not null unique,tipo text not null,estado text not null default 'pendiente' check(estado in ('pendiente','extraido','revisado')),datos jsonb,visible_importador boolean not null default false,vence_el date,reviewed_by uuid references auth.users(id),reviewed_at timestamptz,created_at timestamptz not null default now(),foreign key(empresa_id,embarque_id) references public.embarques(empresa_id,id),check(ruta like empresa_id::text||'/'||id::text||'.%'));
create index on public.documentos(empresa_id,embarque_id);
create table public.eventos(id uuid primary key default gen_random_uuid(),empresa_id uuid not null,embarque_id uuid not null,actor_id uuid,accion text not null,created_at timestamptz not null default now(),foreign key(empresa_id,embarque_id) references public.embarques(empresa_id,id));
create table public.audit_log(id uuid primary key default gen_random_uuid(),empresa_id uuid not null references public.empresas(id),actor_id uuid,accion text not null,tabla text not null,registro_id uuid,antes jsonb,despues jsonb,created_at timestamptz not null default now());
create index on public.audit_log(empresa_id,created_at desc);
create table public.notificaciones(id uuid primary key default gen_random_uuid(),empresa_id uuid not null references public.empresas(id),embarque_id uuid not null references public.embarques(id),usuario_id uuid not null references public.usuarios(id),tipo text not null,clave text not null unique,mensaje text not null,estado text not null default 'pendiente' check(estado in ('pendiente','enviando','enviado','error')),intentos integer not null default 0,lease_until timestamptz,created_at timestamptz not null default now());
create table public.ai_usage(id uuid primary key default gen_random_uuid(),empresa_id uuid not null references public.empresas(id),usuario_id uuid not null,created_at timestamptz not null default now());

create function private.my_company() returns uuid language sql stable security definer set search_path='' as $$ select empresa_id from public.usuarios where id=auth.uid() and coalesce(auth.jwt()->>'aal','')='aal2' $$;
create function private.my_role() returns text language sql stable security definer set search_path='' as $$ select rol from public.usuarios where id=auth.uid() and coalesce(auth.jwt()->>'aal','')='aal2' $$;
create function private.staff(e uuid) returns boolean language sql stable security definer set search_path='' as $$ select e=private.my_company() and private.my_role() in ('owner','gerente','ejecutivo') $$;
create function private.can_read_shipment(e uuid,s uuid) returns boolean language sql stable security definer set search_path='' as $$ select e=private.my_company() and exists(select 1 from public.embarques where id=s and empresa_id=e and (private.my_role() in ('owner','gerente','ejecutivo') or importador_id=auth.uid())) $$;
revoke all on all functions in schema private from public;
grant execute on all functions in schema private to authenticated;

alter table public.empresas enable row level security;
alter table public.usuarios enable row level security;
alter table public.embarques enable row level security;
alter table public.documentos enable row level security;
alter table public.eventos enable row level security;
alter table public.audit_log enable row level security;
alter table public.notificaciones enable row level security;
alter table public.ai_usage enable row level security;

create policy company_read on public.empresas for select to authenticated using(id=private.my_company());
create policy users_read on public.usuarios for select to authenticated using(empresa_id=private.my_company() and (id=auth.uid() or private.my_role() in ('owner','gerente') or (private.my_role()='ejecutivo' and rol='importador')));
create policy shipment_read on public.embarques for select to authenticated using(private.can_read_shipment(empresa_id,id));
create policy shipment_insert on public.embarques for insert to authenticated with check(private.staff(empresa_id));
create policy shipment_update on public.embarques for update to authenticated using(private.staff(empresa_id)) with check(private.staff(empresa_id));
create policy document_read on public.documentos for select to authenticated using(private.can_read_shipment(empresa_id,embarque_id) and (private.staff(empresa_id) or visible_importador));
create policy document_insert on public.documentos for insert to authenticated with check(private.staff(empresa_id));
create policy document_update on public.documentos for update to authenticated using(private.staff(empresa_id)) with check(private.staff(empresa_id));
create policy document_delete on public.documentos for delete to authenticated using(private.staff(empresa_id) and estado='pendiente');
create policy event_read on public.eventos for select to authenticated using(private.can_read_shipment(empresa_id,embarque_id));
create policy audit_read on public.audit_log for select to authenticated using(empresa_id=private.my_company() and private.my_role() in ('owner','gerente'));
create policy notification_read on public.notificaciones for select to authenticated using(empresa_id=private.my_company() and (usuario_id=auth.uid() or private.my_role() in ('owner','gerente')));
create policy usage_read on public.ai_usage for select to authenticated using(empresa_id=private.my_company() and private.my_role()='owner');

-- No client insert/update grants on membership, plans, audit, events or queue.
revoke all on public.empresas,public.usuarios,public.embarques,public.documentos,public.eventos,public.audit_log,public.notificaciones,public.ai_usage from anon,authenticated;
grant select on public.empresas,public.usuarios,public.embarques,public.documentos,public.eventos,public.audit_log,public.notificaciones,public.ai_usage to authenticated;
grant insert,update on public.embarques to authenticated;
grant insert,update,delete on public.documentos to authenticated;

create function private.guard_row() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if TG_OP='UPDATE' and (new.id<>old.id or new.empresa_id<>old.empresa_id or new.created_at<>old.created_at) then raise exception 'Identidad inmutable'; end if;
 if TG_TABLE_NAME='documentos' then
  if TG_OP='UPDATE' and (new.embarque_id<>old.embarque_id or new.ruta<>old.ruta or new.nombre<>old.nombre) then raise exception 'Documento original inmutable'; end if;
  if new.estado='revisado' then
   if new.datos is null or jsonb_typeof(new.datos)<>'object' then raise exception 'Datos revisados requeridos'; end if;
   new.reviewed_by=auth.uid(); new.reviewed_at=now();
  else new.reviewed_by=null; new.reviewed_at=null; end if;
 elsif new.importador_id is not null and not exists(select 1 from public.usuarios where id=new.importador_id and empresa_id=new.empresa_id and rol='importador') then raise exception 'Importador inválido';
 end if;
 return new;
end $$;
create trigger guard_shipment before insert or update on public.embarques for each row execute function private.guard_row();
create trigger guard_document before insert or update on public.documentos for each row execute function private.guard_row();

create function private.audit_change() returns trigger language plpgsql security definer set search_path='' as $$
declare rowdata jsonb; e uuid; s uuid; msg text;
begin
 rowdata=case when TG_OP='DELETE' then to_jsonb(old) else to_jsonb(new) end;
 e=case when TG_TABLE_NAME='empresas' then (rowdata->>'id')::uuid else (rowdata->>'empresa_id')::uuid end;
 insert into public.audit_log(empresa_id,actor_id,accion,tabla,registro_id,antes,despues) values(e,auth.uid(),TG_OP,TG_TABLE_NAME,(rowdata->>'id')::uuid,case when TG_OP<>'INSERT' then to_jsonb(old) end,case when TG_OP<>'DELETE' then to_jsonb(new) end);
 if TG_TABLE_NAME='embarques' then
  s=(rowdata->>'id')::uuid;
  if TG_OP='INSERT' then msg='Embarque creado'; elsif TG_OP='UPDATE' and old.estado<>new.estado then msg='Estado actualizado: '||new.estado; else return coalesce(new,old); end if;
  insert into public.eventos(empresa_id,embarque_id,actor_id,accion) values(e,s,auth.uid(),msg);
  if TG_OP='UPDATE' then insert into public.notificaciones(empresa_id,embarque_id,usuario_id,tipo,clave,mensaje) select e,s,u.id,'estado',gen_random_uuid()::text,msg||' · '||(rowdata->>'referencia') from public.usuarios u where u.empresa_id=e and (u.rol in ('owner','gerente') or u.id=(rowdata->>'importador_id')::uuid); end if;
 elsif TG_TABLE_NAME='documentos' then
  s=(rowdata->>'embarque_id')::uuid;
  insert into public.eventos(empresa_id,embarque_id,actor_id,accion) values(e,s,auth.uid(),case when TG_OP='INSERT' then 'Documento cargado' when TG_OP='DELETE' then 'Carga de documento cancelada' else 'Documento actualizado' end);
 end if;
 return coalesce(new,old);
end $$;
create trigger audit_company after insert or update on public.empresas for each row execute function private.audit_change();
create trigger audit_user after insert or update or delete on public.usuarios for each row execute function private.audit_change();
create trigger audit_shipment after insert or update on public.embarques for each row execute function private.audit_change();
create trigger audit_document after insert or update or delete on public.documentos for each row execute function private.audit_change();

create function public.bootstrap_company(nombre text,persona text) returns uuid language plpgsql security definer set search_path='' as $$
declare e uuid;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception 'Segundo factor requerido'; end if;
 perform pg_advisory_xact_lock(hashtext(auth.uid()::text));
 if exists(select 1 from public.usuarios where id=auth.uid()) then raise exception 'Ya perteneces a una empresa'; end if;
 if length(persona) not between 2 and 100 then raise exception 'Nombre inválido'; end if;
 insert into public.empresas(nombre) values(nombre) returning id into e;
 insert into public.usuarios(id,empresa_id,nombre,rol) values(auth.uid(),e,persona,'owner');
 return e;
end $$;
create function public.add_member(email text,rol text) returns void language plpgsql security definer set search_path='' as $$
declare target uuid; e uuid=private.my_company();
begin
 if private.my_role() is distinct from 'owner' or rol not in ('gerente','ejecutivo','importador') then raise exception 'Acceso denegado'; end if;
 select id into target from auth.users u where lower(u.email)=lower(add_member.email) and u.email_confirmed_at is not null;
 if target is null then raise exception 'No existe una cuenta confirmada con ese correo'; end if;
 insert into public.usuarios(id,empresa_id,nombre,rol) values(target,e,split_part(email,'@',1),rol);
end $$;
create function public.log_action(accion text,tabla text,registro uuid default null) returns void language plpgsql security definer set search_path='' as $$
declare e uuid=private.my_company();
begin
 if e is null or length(accion)>100 or length(tabla)>50 then raise exception 'Acceso denegado'; end if;
 insert into public.audit_log(empresa_id,actor_id,accion,tabla,registro_id) values(e,auth.uid(),accion,tabla,registro);
end $$;
create function public.reserve_extraction() returns void language plpgsql security definer set search_path='' as $$
declare e uuid=private.my_company();
begin
 if not coalesce(private.staff(e),false) or not exists(select 1 from public.empresas where id=e and plan='pro') then raise exception 'Se requiere plan Pro y rol operativo'; end if;
 perform pg_advisory_xact_lock(hashtext(e::text));
 if (select count(*) from public.ai_usage where empresa_id=e and created_at>now()-interval '1 hour')>=30 then raise exception 'Límite temporal de extracción alcanzado'; end if;
 insert into public.ai_usage(empresa_id,usuario_id) values(e,auth.uid());
 insert into public.audit_log(empresa_id,actor_id,accion,tabla) values(e,auth.uid(),'EXTRACCION_SOLICITADA','documentos');
end $$;
revoke all on function public.bootstrap_company(text,text),public.add_member(text,text),public.log_action(text,text,uuid),public.reserve_extraction() from public;
grant execute on function public.bootstrap_company(text,text),public.add_member(text,text),public.log_action(text,text,uuid),public.reserve_extraction() to authenticated;

-- Private bucket. Policy binds path to an authorized document, not just a guessed prefix.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('documentos','documentos',false,4194304,array['application/pdf','image/png','image/jpeg']) on conflict(id) do nothing;
create policy storage_document_read on storage.objects for select to authenticated using(bucket_id='documentos' and exists(select 1 from public.documentos d where d.ruta=name));
create policy storage_document_insert on storage.objects for insert to authenticated with check(bucket_id='documentos' and exists(select 1 from public.documentos d where d.ruta=name and private.staff(d.empresa_id)));
create policy storage_document_delete on storage.objects for delete to authenticated using(bucket_id='documentos' and exists(select 1 from public.documentos d where d.ruta=name and private.staff(d.empresa_id) and d.estado='pendiente'));
