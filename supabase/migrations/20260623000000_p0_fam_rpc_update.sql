-- supabase/migrations/20260623000000_p0_fam_rpc_update.sql
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
    return jsonb_build_object('group_id', null);
  end if;

  select jsonb_build_object(
    'group_id', v_group_id,
    'group_name', (select name from public.family_groups where id = v_group_id limit 1),
    'pending_requests', (
      select count(*) from public.family_members where group_id = v_group_id and status = 'pending'
    ),
    'open_tasks', (
      select count(*) from public.family_tasks where group_id = v_group_id and status in ('open','in_progress','overdue','escalated')
    ),
    'urgent_alerts', (
      select count(*) from public.family_alerts where group_id = v_group_id and status = 'open' and severity = 'critical'
    ),
    'top_tasks', (
      select coalesce(jsonb_agg(t), '[]'::jsonb)
      from (
        select id, title, description, status, priority, due_at, assigned_to
        from public.family_tasks
        where group_id = v_group_id and status != 'done'
        order by due_at asc nulls last
        limit 3
      ) t
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
