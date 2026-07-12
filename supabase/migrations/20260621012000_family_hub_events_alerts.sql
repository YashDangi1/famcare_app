-- supabase/migrations/20260621012000_family_hub_events_alerts.sql
create table if not exists public.family_events (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.family_groups(id) on delete cascade,
  patient_user_id uuid not null references public.profiles(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete set null,
  event_type text not null check (
    event_type in (
      'appointment',
      'task_due',
      'care_visit',
      'med_support_window',
      'routine',
      'custom'
    )
  ),
  title text not null,
  description text,
  start_at timestamptz not null,
  end_at timestamptz,
  is_all_day boolean not null default false,
  recurrence_rule text,
  linked_task_id uuid references public.family_tasks(id) on delete set null,
  linked_appointment_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.family_alerts (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.family_groups(id) on delete cascade,
  patient_user_id uuid not null references public.profiles(id) on delete cascade,
  recipient_user_id uuid not null references public.profiles(id) on delete cascade,
  category text not null check (
    category in (
      'missed_dose',
      'low_stock',
      'appointment_due',
      'appointment_unassigned',
      'vitals_due',
      'abnormal_vitals',
      'task_overdue',
      'record_uploaded',
      'emergency'
    )
  ),
  severity text not null default 'warning' check (
    severity in ('info', 'warning', 'critical')
  ),
  source_table text,
  source_id uuid,
  title text not null,
  message text not null,
  escalation_level smallint not null default 1,
  status text not null default 'open' check (
    status in ('open', 'acknowledged', 'resolved', 'dismissed')
  ),
  acknowledged_at timestamptz,
  acknowledged_by uuid references public.profiles(id) on delete set null,
  resolved_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

drop trigger if exists trg_family_events_updated_at on public.family_events;
create trigger trg_family_events_updated_at
before update on public.family_events
for each row execute function public.set_updated_at();
