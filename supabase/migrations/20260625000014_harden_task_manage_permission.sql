-- supabase/migrations/20260625000014_harden_task_manage_permission.sql

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
  v_can_manage boolean;
begin
  select group_id into v_group_id from public.family_tasks where id = p_task_id;
  if v_group_id is null then
    return false;
  end if;

  select role, status, can_manage_tasks into v_role, v_status, v_can_manage
  from public.family_members 
  where group_id = v_group_id and user_id = auth.uid();

  if v_status != 'approved' then
    return false;
  end if;

  -- Require explicitly given can_manage_tasks permission or admin role
  if v_role = 'admin' or v_can_manage = true then
    return true;
  end if;

  return false;
end;
$$;
