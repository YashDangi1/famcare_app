-- supabase/migrations/20260625000003_expand_family_dashboard_rpc.sql

create or replace function public.rpc_get_family_dashboard()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group_id uuid;
  v_group_name text;
  v_my_role text;
  v_result jsonb;
  v_patient_id uuid;
begin
  select fm.group_id, fg.name, fm.role
  into v_group_id, v_group_name, v_my_role
  from public.family_members fm
  join public.family_groups fg on fg.id = fm.group_id
  where fm.user_id = auth.uid()
    and fm.status = 'approved'
  limit 1;

  if v_group_id is null then
    return jsonb_build_object('group_id', null);
  end if;

  -- Attempt to find a patient in this group (e.g. the admin or primary care receiver)
  select user_id into v_patient_id
  from public.family_members
  where group_id = v_group_id
  order by role asc -- 'admin' comes first
  limit 1;

  select jsonb_build_object(
    'group_id', v_group_id,
    'group_name', v_group_name,
    'my_role', v_my_role,
    'pending_requests', (
      select count(*) from public.family_members where group_id = v_group_id and status = 'pending'
    ),
    'open_tasks', (
      select count(*) from public.family_tasks where group_id = v_group_id and status in ('open','in_progress','overdue','escalated')
    ),
    'urgent_alerts', (
      select count(*) from public.family_alerts where group_id = v_group_id and status = 'open' and severity = 'critical'
    ),
    'today_summary', (
      select jsonb_build_object(
        'meds_due', (
            select count(*) from public.medications m where m.user_id = v_patient_id and m.is_active = true and m.is_prn = false
        ),
        'meds_taken', (
            select count(*) from public.medicine_logs ml where ml.user_id = v_patient_id and date(ml.logged_at at time zone 'utc') = current_date and ml.status = 'taken'
        ),
        'tasks_due_today', (
            select count(*) from public.family_tasks ft where ft.group_id = v_group_id and date(ft.due_at at time zone 'utc') = current_date and ft.status not in ('done', 'cancelled')
        ),
        'appointments_today', (
            select count(*) from public.appointments a where a.patient_user_id = v_patient_id and date(a.scheduled_at at time zone 'utc') = current_date
        )
      )
    ),
    'top_open_tasks', (
      select coalesce(jsonb_agg(t), '[]'::jsonb)
      from (
        select ft.id, ft.title, ft.priority, ft.due_at, ft.status,
               p.full_name as assigned_to_name
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
    ),
    'upcoming_events', (
      select coalesce(jsonb_agg(e), '[]'::jsonb)
      from (
        select id, title, event_type, start_time
        from public.family_events
        where group_id = v_group_id and start_time >= now()
        order by start_time asc
        limit 3
      ) e
    ),
    'emergency_profile_ready', (
      select case when count(*) > 0 then true else false end
      from public.medical_profiles
      where user_id = v_patient_id
    )
  ) into v_result;

  return v_result;
end;
$$;
