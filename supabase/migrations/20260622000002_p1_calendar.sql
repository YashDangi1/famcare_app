-- supabase/migrations/20260622000002_p1_calendar.sql

-- P1-DB-01: Shared Family Calendar Aggregation RPC
create or replace function public.rpc_get_family_calendar(
  p_group_id uuid,
  p_from timestamptz,
  p_to timestamptz
)
returns setof jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Ensure user has access
  if not public.is_family_group_member(p_group_id) then
    return;
  end if;

  return query
  with
  -- 1. Explicit Family Events
  raw_events as (
    select
      id,
      group_id,
      patient_user_id,
      created_by,
      event_type,
      title,
      description,
      start_at,
      end_at,
      is_all_day,
      recurrence_rule,
      linked_task_id,
      linked_appointment_id,
      metadata,
      created_at,
      updated_at
    from public.family_events
    where group_id = p_group_id
      and start_at >= p_from
      and start_at <= p_to
  ),
  
  -- 2. Synthesized Appointments
  synth_appointments as (
    select
      a.id as id,
      fm.group_id as group_id,
      a.user_id as patient_user_id,
      a.user_id as created_by,
      'appointment' as event_type,
      coalesce(a.specialty, a.clinic_name, 'Doctor Visit') as title,
      a.visit_reason as description,
      a.appointment_date as start_at,
      (a.appointment_date + interval '1 hour') as end_at,
      false as is_all_day,
      null as recurrence_rule,
      null::uuid as linked_task_id,
      a.id as linked_appointment_id,
      jsonb_build_object('clinic_name', a.clinic_name, 'status', a.status) as metadata,
      a.created_at as created_at,
      a.updated_at as updated_at
    from public.appointments a
    join public.family_members fm on fm.user_id = a.user_id
    where fm.group_id = p_group_id
      and fm.status = 'approved'
      and a.appointment_date >= p_from
      and a.appointment_date <= p_to
      and not exists (
        select 1 from public.family_events fe 
        where fe.linked_appointment_id = a.id
      )
  ),

  -- 3. Synthesized Tasks
  synth_tasks as (
    select
      t.id as id,
      t.group_id as group_id,
      t.patient_user_id as patient_user_id,
      t.created_by as created_by,
      'task_due' as event_type,
      t.title as title,
      t.description as description,
      t.due_at as start_at,
      (t.due_at + interval '30 minutes') as end_at,
      false as is_all_day,
      null as recurrence_rule,
      t.id as linked_task_id,
      null::uuid as linked_appointment_id,
      jsonb_build_object('status', t.status, 'priority', t.priority) as metadata,
      t.created_at as created_at,
      t.updated_at as updated_at
    from public.family_tasks t
    where t.group_id = p_group_id
      and t.due_at is not null
      and t.due_at >= p_from
      and t.due_at <= p_to
      and t.status not in ('done', 'dismissed')
      and not exists (
        select 1 from public.family_events fe
        where fe.linked_task_id = t.id
      )
  ),

  -- Combine them all
  all_events as (
    select * from raw_events
    union all
    select * from synth_appointments
    union all
    select * from synth_tasks
  )

  -- Output as JSON
  select row_to_json(all_events)::jsonb
  from all_events
  order by start_at asc;
end;
$$;

-- Reload schema
NOTIFY pgrst, 'reload schema';
