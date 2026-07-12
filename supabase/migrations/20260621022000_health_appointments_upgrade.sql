-- supabase/migrations/20260621022000_health_appointments_upgrade.sql

alter table public.appointments
  add column if not exists specialty text,
  add column if not exists clinic_name text,
  add column if not exists clinic_address text,
  add column if not exists visit_reason text,
  add column if not exists status text not null default 'upcoming'
    check (status in ('upcoming', 'completed', 'cancelled', 'missed')),
  add column if not exists linked_record_ids uuid[] not null default '{}',
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

create table if not exists public.appointment_notes (
  id uuid primary key default gen_random_uuid(),
  appointment_id uuid not null references public.appointments(id) on delete cascade,
  pre_visit_questions text,
  visit_summary text,
  follow_up_plan text,
  next_steps text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (appointment_id)
);

create index if not exists idx_appointments_user_status_date
  on public.appointments(user_id, status, appointment_date asc);

alter table public.appointment_notes enable row level security;

create policy appointment_notes_select_own
on public.appointment_notes
for select
using (
  exists (
    select 1 from public.appointments a
    where a.id = appointment_id and a.user_id = auth.uid()
  )
);

create policy appointment_notes_manage_own
on public.appointment_notes
for all
using (
  exists (
    select 1 from public.appointments a
    where a.id = appointment_id and a.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.appointments a
    where a.id = appointment_id and a.user_id = auth.uid()
  )
);
