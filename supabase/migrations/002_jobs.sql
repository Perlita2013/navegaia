-- Narrow privileged RPCs for machine jobs. Never use service_role for user routes.
create function public.claim_notifications() returns table(id uuid,email text,mensaje text) language plpgsql security definer set search_path='' as $$
declare today date=(now() at time zone 'America/Santiago')::date;
begin
 insert into public.notificaciones(empresa_id,embarque_id,usuario_id,tipo,clave,mensaje)
 select s.empresa_id,s.id,u.id,'demurrage',s.id::text||':'||u.id::text||':demurrage:'||today::text,
 s.referencia||': '||greatest(0,today-s.eta-s.free_time)::text||' días sobre free time; '||greatest(0,s.free_time-(today-s.eta))::text||' días restantes. Estimación desde ETA; confirma condiciones con la naviera.'
 from public.embarques s join public.usuarios u on u.empresa_id=s.empresa_id and (u.rol in ('owner','gerente') or u.id=s.importador_id)
 where s.estado<>'liberado' and today>=s.eta and s.free_time-(today-s.eta)<=3
 on conflict(clave) do nothing;
 insert into public.notificaciones(empresa_id,embarque_id,usuario_id,tipo,clave,mensaje)
 select d.empresa_id,d.embarque_id,u.id,'vencimiento',d.id::text||':'||u.id::text||':vencimiento:'||today::text,
 'Vencimiento documental: '||d.nombre||' · '||s.referencia||' · Fecha: '||d.vence_el::text
 from public.documentos d join public.embarques s on s.id=d.embarque_id join public.usuarios u on u.empresa_id=d.empresa_id and (u.rol in ('owner','gerente') or (u.id=s.importador_id and d.visible_importador))
 where d.vence_el is not null and d.vence_el<=today+3 and s.estado<>'liberado'
 on conflict(clave) do nothing;
 return query with claimed as (
 select n.id from public.notificaciones n where (n.estado in ('pendiente','error') or (n.estado='enviando' and n.lease_until<now())) and n.intentos<5 order by n.created_at limit 5 for update skip locked
 ), updated as (
 update public.notificaciones n set estado='enviando',intentos=n.intentos+1,lease_until=now()+interval '5 minutes' from claimed c where n.id=c.id returning n.id,n.usuario_id,n.mensaje
 ) select t.id,a.email::text,t.mensaje from updated t join auth.users a on a.id=t.usuario_id;
end $$;
create function public.finish_notification(notification_id uuid,sent boolean) returns void language plpgsql security definer set search_path='' as $$
declare e uuid;
begin
 update public.notificaciones set estado=case when sent then 'enviado' else 'error' end,lease_until=null where id=notification_id and estado='enviando' returning empresa_id into e;
 if e is not null then insert into public.audit_log(empresa_id,accion,tabla,registro_id) values(e,case when sent then 'EMAIL_ENVIADO' else 'EMAIL_ERROR' end,'notificaciones',notification_id); end if;
end $$;
-- Subscription plan is derived from a freshly retrieved Stripe subscription, not user input.
create function public.apply_subscription(company_id uuid,subscription_id text,active boolean) returns void language plpgsql security definer set search_path='' as $$
begin
 update public.empresas set plan=case when active then 'pro' else 'esencial' end,stripe_subscription_id=subscription_id where id=company_id;
end $$;
revoke all on function public.claim_notifications(),public.finish_notification(uuid,boolean),public.apply_subscription(uuid,text,boolean) from public,anon,authenticated;
grant execute on function public.claim_notifications(),public.finish_notification(uuid,boolean),public.apply_subscription(uuid,text,boolean) to service_role;
revoke all on function private.guard_row(),private.audit_change() from public;
