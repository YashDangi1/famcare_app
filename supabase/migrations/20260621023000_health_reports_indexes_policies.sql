-- supabase/migrations/20260621023000_health_reports_indexes_policies.sql

create table if not exists public.health_report_exports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  report_type text not null check (
    report_type in ('doctor_visit', 'vitals_summary', 'symptom_summary', 'full_health_summary')
  ),
  date_range_start date,
  date_range_end date,
  file_url text,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_health_report_exports_user_created
  on public.health_report_exports(user_id, created_at desc);

alter table public.health_report_exports enable row level security;

create policy health_report_exports_select_own
on public.health_report_exports
for select
using (auth.uid() = user_id);

create policy health_report_exports_insert_own
on public.health_report_exports
for insert
with check (auth.uid() = user_id);
