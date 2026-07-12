-- supabase/migrations/20260625000008_harden_family_task_rpcs_auth.sql

-- Helper function to check if user has permission to manage a task's group
create or replace function public.check_task_manage_permission(p_task_id uuid)
returns boolean
language plpgsql
security definer
as $$
declare
  v_group_id uuid;
  v_role text;
  v_status text;
begin
  select group_id into v_group_id from public.family_tasks where id = p_task_id;
  if v_group_id is null then
    return false;
  end if;

  select role, status into v_role, v_status 
  from public.family_members 
  where group_id = v_group_id and user_id = auth.uid();

  if v_status != 'approved' then
    return false;
  end if;

  -- Allow approved members to manage tasks for now, or tighten if specific roles are required
  return true; 
end;
$$;

-- 1. rpc_assign_family_task
create or replace function public.rpc_assign_family_task(
  p_task_id uuid,
  p_assigned_to uuid,
  p_due_at timestamptz,
  p_comment text
)
returns public.family_tasks
language plpgsql
security definer
set search_path = public
as $$
declare
  v_task public.family_tasks;
  v_has_permission boolean;
begin
  v_has_permission := public.check_task_manage_permission(p_task_id);
  if not v_has_permission then
    raise exception 'Unauthorized to manage this task';
  end if;

  update public.family_tasks
  set 
    assigned_to = p_assigned_to,
    due_at = p_due_at,
    updated_at = now()
  where id = p_task_id
  returning * into v_task;

  if v_task is null then
    raise exception 'Task not found';
  end if;

  if p_comment is null or p_comment = '' then
    p_comment := 'Task was assigned.';
  end if;

  insert into public.family_task_comments (task_id, author_user_id, comment)
  values (p_task_id, auth.uid(), p_comment);

  insert into public.family_updates(group_id, patient_user_id, author_user_id, update_type, content, linked_task_id)
  values (v_task.group_id, v_task.patient_user_id, auth.uid(), 'general', 'Task assigned: ' || v_task.title, v_task.id);

  return v_task;
end;
$$;

-- 2. rpc_reassign_family_task
create or replace function public.rpc_reassign_family_task(
  p_task_id uuid,
  p_assigned_to uuid,
  p_comment text
)
returns public.family_tasks
language plpgsql
security definer
set search_path = public
as $$
declare
  v_task public.family_tasks;
  v_has_permission boolean;
begin
  v_has_permission := public.check_task_manage_permission(p_task_id);
  if not v_has_permission then
    raise exception 'Unauthorized to manage this task';
  end if;

  update public.family_tasks
  set 
    assigned_to = p_assigned_to,
    updated_at = now()
  where id = p_task_id
  returning * into v_task;

  if v_task is null then
    raise exception 'Task not found';
  end if;

  if p_comment is null or p_comment = '' then
    p_comment := 'Task was reassigned.';
  end if;

  insert into public.family_task_comments (task_id, author_user_id, comment)
  values (p_task_id, auth.uid(), p_comment);

  insert into public.family_updates(group_id, patient_user_id, author_user_id, update_type, content, linked_task_id)
  values (v_task.group_id, v_task.patient_user_id, auth.uid(), 'general', 'Task reassigned: ' || v_task.title, v_task.id);

  return v_task;
end;
$$;

-- 3. rpc_update_task_status
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
  v_update_type text;
  v_has_permission boolean;
  v_old_status text;
begin
  select status into v_old_status from public.family_tasks where id = p_task_id;
  
  if v_old_status is null then
    raise exception 'Task not found';
  end if;

  v_has_permission := public.check_task_manage_permission(p_task_id);
  if not v_has_permission then
    raise exception 'Unauthorized to manage this task';
  end if;

  if p_status not in ('open', 'in_progress', 'done', 'cancelled', 'overdue', 'escalated') then
    raise exception 'Invalid task status';
  end if;

  if p_status = 'done' then
    v_update_type := 'task_completed';
    update public.family_tasks
    set status = p_status,
        completed_at = now(),
        completed_by = auth.uid(),
        updated_at = now()
    where id = p_task_id
    returning * into v_task;
  else
    v_update_type := 'general';
    update public.family_tasks
    set status = p_status,
        updated_at = now()
    where id = p_task_id
    returning * into v_task;
  end if;

  insert into public.family_updates(group_id, patient_user_id, author_user_id, update_type, content, linked_task_id)
  values (v_task.group_id, v_task.patient_user_id, auth.uid(), v_update_type, 'Task marked as ' || p_status || ': ' || v_task.title, v_task.id);

  return v_task;
end;
$$;
