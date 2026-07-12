-- supabase/migrations/20260621011000_family_hub_tasks_updates.sql
create table if not exists public.family_tasks (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.family_groups(id) on delete cascade,
  patient_user_id uuid not null references public.profiles(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete set null,
  assigned_to uuid references public.profiles(id) on delete set null,
  completed_by uuid references public.profiles(id) on delete set null,
  task_type text not null check (
    task_type in (
      'medicine_followup',
      'refill',
      'appointment_support',
      'appointment_prep',
      'vitals_check',
      'upload_record',
      'wellness_checkin',
      'insurance',
      'custom'
    )
  ),
  title text not null,
  description text,
  priority text not null default 'medium' check (
    priority in ('low', 'medium', 'high', 'critical')
  ),
  status text not null default 'open' check (
    status in ('open', 'in_progress', 'done', 'skipped', 'overdue', 'escalated', 'cancelled')
  ),
  linked_medication_id uuid,
  linked_appointment_id uuid,
  linked_record_id uuid,
  due_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  escalation_level smallint not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.family_task_comments (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.family_tasks(id) on delete cascade,
  author_user_id uuid not null references public.profiles(id) on delete cascade,
  comment text not null,
  attachment_url text,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.family_updates (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.family_groups(id) on delete cascade,
  patient_user_id uuid not null references public.profiles(id) on delete cascade,
  author_user_id uuid not null references public.profiles(id) on delete cascade,
  update_type text not null check (
    update_type in (
      'checkin',
      'symptom',
      'medication_note',
      'appointment_summary',
      'record_uploaded',
      'task_completed',
      'vitals_note',
      'emergency_note',
      'general'
    )
  ),
  severity text not null default 'info' check (
    severity in ('info', 'warning', 'critical')
  ),
  content text not null,
  image_url text,
  linked_task_id uuid references public.family_tasks(id) on delete set null,
  linked_appointment_id uuid,
  linked_medicine_log_id uuid,
  linked_vital_id uuid,
  is_pinned boolean not null default false,
  created_at timestamptz not null default timezone('utc', now())
);

drop trigger if exists trg_family_tasks_updated_at on public.family_tasks;
create trigger trg_family_tasks_updated_at
before update on public.family_tasks
for each row execute function public.set_updated_at();
