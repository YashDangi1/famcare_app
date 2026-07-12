-- supabase/migrations/20260621020000_health_symptoms.sql

create table if not exists public.symptoms (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  symptom_type text not null,
  severity smallint not null check (severity between 1 and 5),
  started_at timestamptz not null,
  duration_minutes integer,
  notes text,
  possible_trigger text,
  linked_medication_id uuid,
  linked_vital_id uuid,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_symptoms_user_started_at
  on public.symptoms(user_id, started_at desc);

create index if not exists idx_symptoms_user_type
  on public.symptoms(user_id, symptom_type);

alter table public.symptoms enable row level security;

create policy symptoms_select_own
on public.symptoms
for select
using (auth.uid() = user_id);

create policy symptoms_insert_own
on public.symptoms
for insert
with check (auth.uid() = user_id or auth.uid() = created_by);

create policy symptoms_update_own
on public.symptoms
for update
using (auth.uid() = user_id or auth.uid() = created_by)
with check (auth.uid() = user_id or auth.uid() = created_by);
