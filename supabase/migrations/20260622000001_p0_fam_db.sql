-- supabase/migrations/20260622000001_p0_fam_db.sql

-- P0-DB-03: Expand rpc_get_family_dashboard() to include group_name and top_tasks
create or replace function public.rpc_get_family_dashboard()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group_id uuid;
  v_group_name text;
  v_result jsonb;
begin
  select fm.group_id, fg.name
  into v_group_id, v_group_name
  from public.family_members fm
  join public.family_groups fg on fg.id = fm.group_id
  where fm.user_id = auth.uid()
    and fm.status = 'approved'
  limit 1;

  if v_group_id is null then
    return jsonb_build_object('group_id', null);
  end if;

  select jsonb_build_object(
    'group_id', v_group_id,
    'group_name', v_group_name,
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
        select ft.id, ft.title, ft.priority, ft.due_at, ft.status,
               p.full_name as assignee_name
        from public.family_tasks ft
        left join public.profiles p on p.id = ft.assigned_to
        where ft.group_id = v_group_id
          and ft.status in ('open','in_progress','overdue')
        order by ft.priority desc, ft.due_at asc nulls last
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

-- P0-DB-04: Add RPCs for task management
create or replace function public.rpc_assign_family_task(
  p_task_id uuid,
  p_assignee_id uuid
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
  set assigned_to = p_assignee_id,
      updated_at = timezone('utc', now())
  where id = p_task_id
    and public.is_family_group_member(group_id)
  returning * into v_task;

  -- Add an update log
  insert into public.family_updates(group_id, update_type, content, source_user_id)
  values (v_task.group_id, 'task', 'Task reassigned: ' || v_task.title, auth.uid());

  return v_task;
end;
$$;

create or replace function public.rpc_update_task_status(
  p_task_id uuid,
  p_status text
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
  set status = p_status,
      updated_at = timezone('utc', now())
  where id = p_task_id
    and public.is_family_group_member(group_id)
  returning * into v_task;

  insert into public.family_updates(group_id, update_type, content, source_user_id)
  values (v_task.group_id, 'task', 'Task marked as ' || p_status || ': ' || v_task.title, auth.uid());

  return v_task;
end;
$$;

-- P0-DB-07: Add family_alert_rules RLS policies
alter table public.family_alert_rules enable row level security;

drop policy if exists alert_rules_select on public.family_alert_rules;
create policy alert_rules_select on public.family_alert_rules 
for select using (public.is_family_group_member(group_id));

drop policy if exists alert_rules_insert on public.family_alert_rules;
create policy alert_rules_insert on public.family_alert_rules 
for insert with check (public.is_family_group_admin(group_id));

drop policy if exists alert_rules_update on public.family_alert_rules;
create policy alert_rules_update on public.family_alert_rules 
for update using (public.is_family_group_admin(group_id));

drop policy if exists alert_rules_delete on public.family_alert_rules;
create policy alert_rules_delete on public.family_alert_rules 
for delete using (public.is_family_group_admin(group_id));

-- Reload schema
NOTIFY pgrst, 'reload schema';
