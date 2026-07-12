-- supabase/migrations/20260625000012_fix_alert_recipient_logic.sql

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
  v_role text;
  v_status text;
begin
  select * into v_alert from public.family_alerts where id = p_alert_id;
  
  if v_alert is null then
    raise exception 'Alert not found';
  end if;

  select role, status into v_role, v_status
  from public.family_members
  where group_id = v_alert.group_id and user_id = auth.uid();

  if v_status != 'approved' then
    raise exception 'Unauthorized to resolve this alert';
  end if;

  -- Fix: Only recipient (recipient_user_id) or admin can resolve
  if auth.uid() != v_alert.recipient_user_id and v_role != 'admin' then
    raise exception 'Only the recipient or a group admin can resolve alerts';
  end if;

  update public.family_alerts
  set 
    status = 'resolved',
    resolved_at = now()
  where id = p_alert_id
  returning * into v_alert;

  insert into public.family_updates(group_id, patient_user_id, author_user_id, update_type, content)
  values (v_alert.group_id, v_alert.patient_user_id, auth.uid(), 'general', 'Alert resolved: ' || v_alert.title);

  return v_alert;
end;
$$;
