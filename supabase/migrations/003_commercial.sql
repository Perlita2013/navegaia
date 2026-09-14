-- Acceso de plataforma separado de los roles de empresa. Sin acceso transversal a documentos.
create table public.platform_owners(user_id uuid primary key references auth.users(id),created_at timestamptz not null default now());
alter table public.platform_owners enable row level security;
revoke all on public.platform_owners from public,anon,authenticated;
grant select on public.platform_owners to authenticated;
create policy self_access on public.platform_owners for select to authenticated using(user_id=auth.uid() and coalesce(auth.jwt()->>'aal','')='aal2');
create function private.is_platform_owner() returns boolean language sql stable security definer set search_path='' as $$ select coalesce(auth.jwt()->>'aal','')='aal2' and exists(select 1 from public.platform_owners where user_id=auth.uid()) $$;
revoke all on function private.is_platform_owner() from public;
grant execute on function private.is_platform_owner() to authenticated;
create table public.platform_audit(id uuid primary key default gen_random_uuid(),actor_id uuid,accion text not null,empresa_id uuid,detalle jsonb,created_at timestamptz not null default now());
alter table public.platform_audit enable row level security;
revoke all on public.platform_audit from public,anon,authenticated;
grant select on public.platform_audit to authenticated;
create policy owner_audit on public.platform_audit for select to authenticated using(private.is_platform_owner());
alter table public.empresas
 add column plan_comercial text not null default 'emprende' check(plan_comercial in ('emprende','crece','empresa','corporativo')),
 add column estado_comercial text not null default 'piloto' check(estado_comercial in ('piloto','activo','suspendido')),
 add column precio_mensual integer not null default 49900 check(precio_mensual>=0),
 add column limite_embarques integer not null default 25 check(limite_embarques>0),
 add column limite_documentos integer not null default 100 check(limite_documentos>0),
 add column limite_usuarios integer not null default 2 check(limite_usuarios>0),
 add column contrato_inicio date,add column contrato_fin date,
 add constraint contract_dates check((contrato_inicio is null and contrato_fin is null) or (contrato_inicio is not null and contrato_fin is not null and contrato_fin>contrato_inicio)),
 add constraint active_contract check(estado_comercial<>'activo' or contrato_inicio is not null);
-- Las consultas de cupos comparten el inicio de mes de Chile.
create function private.usage_summary(e uuid) returns jsonb language sql volatile security definer set search_path='' as $$
 select jsonb_build_object('embarques',(select count(*) from public.embarques where empresa_id=e and created_at>=date_trunc('month',now() at time zone 'America/Santiago') at time zone 'America/Santiago'),
 'documentos',(select count(*) from public.audit_log where empresa_id=e and tabla='documentos' and accion='INSERT' and created_at>=date_trunc('month',now() at time zone 'America/Santiago') at time zone 'America/Santiago'),
 'usuarios',(select count(*) from public.usuarios where empresa_id=e and rol<>'importador'))
$$;
revoke all on function private.usage_summary(uuid) from public,anon,authenticated;
create function public.platform_access() returns boolean language sql stable security invoker set search_path='' as $$ select private.is_platform_owner() $$;
create function public.platform_overview() returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if not private.is_platform_owner() then raise exception 'Acceso exclusivo Owner NavegaIA'; end if;
 insert into public.platform_audit(actor_id,accion) values(auth.uid(),'CONSULTA_CLIENTES');
 select coalesce(jsonb_agg(to_jsonb(x) order by x.nombre),'[]'::jsonb) into result from (
 select e.id,e.nombre,e.plan_comercial,e.estado_comercial,e.precio_mensual,e.limite_embarques,e.limite_documentos,e.limite_usuarios,e.contrato_inicio,e.contrato_fin,private.usage_summary(e.id) as consumo,
 (select count(*) from public.usuarios u where u.empresa_id=e.id and u.rol='ejecutivo') as ejecutivos,
 (select count(*) from public.usuarios u where u.empresa_id=e.id and u.rol='gerente') as gerentes,
 (select count(*) from public.usuarios u where u.empresa_id=e.id and u.rol='importador') as importadores,
 (select count(*) from public.embarques s where s.empresa_id=e.id and s.estado<>'liberado') as en_seguimiento,
 (select coalesce(jsonb_agg(jsonb_build_object('id',u.id,'nombre',u.nombre,'rol',u.rol) order by u.nombre),'[]'::jsonb) from public.usuarios u where u.empresa_id=e.id) as miembros from public.empresas e
 ) x;
 return jsonb_build_object('clientes',result,'mes',to_char(now() at time zone 'America/Santiago','YYYY-MM'));
end $$;
create function public.platform_update_company(company_id uuid,plan_id text,status text,start_date date,custom_price integer default null,custom_shipments integer default null,custom_documents integer default null,custom_seats integer default null) returns void language plpgsql security definer set search_path='' as $$
declare price integer; ships integer; docs integer; seats integer;
begin
 if not private.is_platform_owner() then raise exception 'Acceso exclusivo Owner NavegaIA'; end if;
 if plan_id is null or plan_id not in ('emprende','crece','empresa','corporativo') or status is null or status not in ('piloto','activo','suspendido') then raise exception 'Plan o estado inválido'; end if;
 perform 1 from public.empresas where id=company_id for update;
 if not found then raise exception 'Empresa no encontrada'; end if;
 if plan_id='emprende' then price=49900;ships=25;docs=100;seats=2;
 elsif plan_id='crece' then price=129900;ships=100;docs=500;seats=5;
 elsif plan_id='empresa' then price=279900;ships=300;docs=1500;seats=12;
 else price=custom_price;ships=custom_shipments;docs=custom_documents;seats=custom_seats;end if;
 if price is null or price<0 or ships is null or ships<1 or docs is null or docs<1 or seats is null or seats<1 then raise exception 'Define precio y cupos'; end if;
 if (select count(*) from public.usuarios where empresa_id=company_id and rol<>'importador')>seats then raise exception 'El equipo supera el cupo del plan'; end if;
 if status='activo' and start_date is null then raise exception 'Define fecha de inicio'; end if;
 update public.empresas set plan_comercial=plan_id,estado_comercial=status,precio_mensual=price,limite_embarques=ships,limite_documentos=docs,limite_usuarios=seats,contrato_inicio=start_date,contrato_fin=case when start_date is null then null else (start_date+interval '1 year')::date end where id=company_id;
 insert into public.platform_audit(actor_id,accion,empresa_id,detalle) values(auth.uid(),'ACTUALIZA_CONTRATO',company_id,jsonb_build_object('plan',plan_id,'estado',status,'inicio',start_date));
end $$;
create function public.company_usage() returns jsonb language plpgsql security definer set search_path='' as $$
declare e uuid=private.my_company(); result jsonb;
begin
 if e is null or coalesce(private.my_role(),'') not in ('owner','gerente') then raise exception 'Acceso denegado'; end if;
 select jsonb_build_object('plan',plan_comercial,'estado',estado_comercial,'precio',precio_mensual,'limite_embarques',limite_embarques,'limite_documentos',limite_documentos,'limite_usuarios',limite_usuarios)||private.usage_summary(e) into result from public.empresas where id=e;
 insert into public.audit_log(empresa_id,actor_id,accion,tabla) values(e,auth.uid(),'CONSULTA_CONSUMO','empresas');
 return result;
end $$;
-- Bloqueo por empresa para serializar altas concurrentes; las fechas de alta no vienen del cliente.
create function private.commercial_quota() returns trigger language plpgsql security definer set search_path='' as $$
declare company public.empresas; used bigint; cap integer; usage jsonb;
begin
 select * into company from public.empresas where id=new.empresa_id for update;
 if not found then raise exception 'Empresa no encontrada'; end if;
 if company.estado_comercial='suspendido' then raise exception 'Empresa suspendida: consulta disponible, nuevas altas bloqueadas'; end if;
 usage=private.usage_summary(new.empresa_id);
 if TG_TABLE_NAME='usuarios' then
  if new.rol='importador' then return new; end if;
  used=(usage->>'usuarios')::bigint;cap=company.limite_usuarios;
 elsif TG_TABLE_NAME='embarques' then new.created_at=now();used=(usage->>'embarques')::bigint;cap=company.limite_embarques;
 else new.created_at=now();used=(usage->>'documentos')::bigint;cap=company.limite_documentos;end if;
 if used>=cap then raise exception 'Cupo del plan alcanzado. Solicita ampliación'; end if;
 return new;
end $$;
create trigger commercial_shipments before insert on public.embarques for each row execute function private.commercial_quota();
create trigger commercial_documents before insert on public.documentos for each row execute function private.commercial_quota();
create trigger commercial_users before insert on public.usuarios for each row execute function private.commercial_quota();
revoke all on function private.commercial_quota() from public;
create or replace function public.add_member(email text,rol text) returns void language plpgsql security definer set search_path='' as $$
declare target uuid; e uuid=private.my_company();
begin
 if coalesce(private.my_role(),'') not in ('owner','gerente') or rol is null or rol not in ('gerente','ejecutivo','importador') or (private.my_role()='gerente' and rol='gerente') then raise exception 'Acceso denegado'; end if;
 select id into target from auth.users u where lower(u.email)=lower(add_member.email) and u.email_confirmed_at is not null;
 if target is null then raise exception 'No existe una cuenta confirmada con ese correo'; end if;
 insert into public.usuarios(id,empresa_id,nombre,rol) values(target,e,split_part(email,'@',1),rol);
end $$;
revoke all on function public.platform_access(),public.platform_overview(),public.platform_update_company(uuid,text,text,date,integer,integer,integer,integer),public.company_usage() from public,anon;
grant execute on function public.platform_access(),public.platform_overview(),public.platform_update_company(uuid,text,text,date,integer,integer,integer,integer),public.company_usage() to authenticated;
-- El primer Owner se habilita por SQL administrativo con UUID confirmado de auth.users.
-- No hay autoasignación por correo, URL ni user_metadata.
