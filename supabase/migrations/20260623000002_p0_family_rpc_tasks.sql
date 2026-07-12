-- supabase/migrations/20260623000002_p0_family_rpc_tasks.sql

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
  -- 1. Update the task
  update public.family_tasks
  set 
    assigned_to = p_assigned_to,
    due_at = p_due_at,
    updated_at = now()
  where id = p_task_id
  returning * into v_task;

  -- 2. Optional: insert a comment about the assignment
  if p_comment is null or p_comment = '' then
    p_comment := 'Task was assigned.';
  end if;

  insert into public.family_task_comments (task_id, user_id, comment)
  values (p_task_id, auth.uid(), p_comment);

  return v_task;
end;
$$;

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
  -- 1. Update the task assignee
  update public.family_tasks
  set 
    assigned_to = p_assigned_to,
    updated_at = now()
  where id = p_task_id
  returning * into v_task;

  -- 2. Insert comment about the reassignment
  if p_comment is null or p_comment = '' then
    p_comment := 'Task was reassigned.';
  end if;

  insert into public.family_task_comments (task_id, user_id, comment)
  values (p_task_id, auth.uid(), p_comment);

  return v_task;
end;
$$;
