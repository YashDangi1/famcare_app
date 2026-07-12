-- supabase/migrations/20260621014000_family_hub_rpc.sql
create or replace function public.rpc_acknowledge_family_alert(p_alert_id uuid)
returns public.family_alerts
language plpgsql
security definer
set search_path = public
as $$
declare
  v_alert public.family_alerts;
begin
  update public.family_alerts
  set status = 'acknowledged',
      acknowledged_at = timezone('utc', now()),
      acknowledged_by = auth.uid()
  where id = p_alert_id
    and (recipient_user_id = auth.uid() or public.is_family_group_admin(group_id))
  returning * into v_alert;

  return v_alert;
end;
$$;

create or replace function public.rpc_complete_family_task(
  p_task_id uuid,
  p_comment text default null
)
returns public.family_tasks
language plpgsql
security definer
set search_path = public
as $$
declare
  v_task public.family_tasks;
begin
  update public.family_tasks
  set status = 'done',
      completed_at = timezone('utc', now()),
      completed_by = auth.uid()
  where id = p_task_id
    and public.is_family_group_member(group_id)
  returning * into v_task;

  if p_comment is not null and length(trim(p_comment)) > 0 then
    insert into public.family_task_comments(task_id, author_user_id, comment)
    values (p_task_id, auth.uid(), p_comment);
  end if;

  return v_task;
end;
$$;

create or replace function public.rpc_get_family_dashboard()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group_id uuid;
  v_result jsonb;
begin
  select fm.group_id
  into v_group_id
  from public.family_members fm
  where fm.user_id = auth.uid()
    and fm.status = 'approved'
  limit 1;

  if v_group_id is null then
    return jsonb_build_object('group', null);
  end if;

  select jsonb_build_object(
    'group_id', v_group_id,
    'pending_requests', (
      select count(*) from public.family_members where group_id = v_group_id and status = 'pending'
    ),
    'open_tasks', (
      select count(*) from public.family_tasks where group_id = v_group_id and status in ('open','in_progress','overdue','escalated')
    ),
    'urgent_alerts', (
      select count(*) from public.family_alerts where group_id = v_group_id and status = 'open' and severity = 'critical'
    ),
    'recent_updates', (
      select coalesce(jsonb_agg(t), '[]'::jsonb)
      from (
        select id, update_type, content, severity, created_at
        from public.family_updates
        where group_id = v_group_id
        order by created_at desc
        limit 5
      ) t
    )
  ) into v_result;

  return v_result;
end;
$$;
