-- supabase/migrations/20260621021000_health_records.sql

create table if not exists public.health_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  category text not null check (
    category in ('prescription', 'lab_report', 'imaging', 'discharge_summary', 'doctor_note', 'vaccine', 'other')
  ),
  title text not null,
  file_url text not null,
  thumb_url text,
  provider_name text,
  record_date date,
  tags text[] not null default '{}',
  linked_appointment_id uuid,
  source text not null default 'manual' check (source in ('manual', 'ocr', 'legacy_prescription')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_health_records_user_category
  on public.health_records(user_id, category);

create index if not exists idx_health_records_user_record_date
  on public.health_records(user_id, record_date desc nulls last);

alter table public.health_records enable row level security;

create policy health_records_select_own
on public.health_records
for select
using (auth.uid() = user_id);

create policy health_records_insert_own
on public.health_records
for insert
with check (auth.uid() = user_id or auth.uid() = created_by);

create policy health_records_update_own
on public.health_records
for update
using (auth.uid() = user_id or auth.uid() = created_by)
with check (auth.uid() = user_id or auth.uid() = created_by);
