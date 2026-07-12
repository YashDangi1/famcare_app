-- supabase/migrations/20260625000000_fix_family_task_rpcs.sql

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
begin
  update public.family_tasks
  set 
    assigned_to = p_assigned_to,
    due_at = p_due_at,
    updated_at = now()
  where id = p_task_id
  returning * into v_task;

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
begin
  update public.family_tasks
  set 
    assigned_to = p_assigned_to,
    updated_at = now()
  where id = p_task_id
  returning * into v_task;

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
begin
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
