-- supabase/migrations/20260625000001_add_rpc_resolve_family_alert.sql

create or replace function public.rpc_resolve_family_alert(
  p_alert_id uuid
)
returns public.family_alerts
language plpgsql
security definer
set search_path = public
as $$
declare
  v_alert public.family_alerts;
begin
  update public.family_alerts
  set 
    status = 'resolved',
    resolved_at = now(),
    resolved_by = auth.uid(),
    updated_at = now()
  where id = p_alert_id
  returning * into v_alert;

  -- Optional: log to family_updates
  if found then
    insert into public.family_updates(group_id, patient_user_id, author_user_id, update_type, severity, content)
    values (v_alert.group_id, v_alert.patient_user_id, auth.uid(), 'general', 'info', 'Alert resolved: ' || v_alert.title);
  end if;

  return v_alert;
end;
$$;
