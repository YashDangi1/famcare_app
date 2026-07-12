-- supabase/migrations/20260625000004_add_weekly_summary_rpc.sql

create or replace function public.rpc_get_weekly_family_summary(
  p_patient_user_id uuid default auth.uid()
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group_id uuid;
  v_result jsonb;
  v_start_date timestamptz := timezone('utc', now()) - interval '7 days';
begin
  select group_id into v_group_id
  from public.family_members
  where user_id = p_patient_user_id
  limit 1;

  if v_group_id is null then
    return jsonb_build_object('error', 'Group not found');
  end if;

  select jsonb_build_object(
    'patient_user_id', p_patient_user_id,
    'start_date', v_start_date,
    'end_date', timezone('utc', now()),
    'meds', (
      select jsonb_build_object(
        'total_due', count(*),
        'total_taken', sum(case when status = 'taken' then 1 else 0 end)
      )
      from public.medicine_logs
      where user_id = p_patient_user_id
        and logged_at >= v_start_date
    ),
    'tasks', (
      select jsonb_build_object(
        'total_due', count(*),
        'total_done', sum(case when status = 'done' then 1 else 0 end)
      )
      from public.family_tasks
      where group_id = v_group_id
        and due_at >= v_start_date
    ),
    'alerts', (
      select count(*)
      from public.family_alerts
      where group_id = v_group_id
        and created_at >= v_start_date
    )
  ) into v_result;

  return v_result;
end;
$$;
