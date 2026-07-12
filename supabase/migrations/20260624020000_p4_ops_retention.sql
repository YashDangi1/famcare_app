-- supabase/migrations/20260624020000_p4_ops_retention.sql

-- 1. Create notification_inbox table
create table if not exists public.notification_inbox (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  category text not null check (category in ('meds', 'family', 'health', 'system')),
  title text not null,
  body text not null,
  severity text not null default 'info' check (severity in ('info', 'warning', 'critical', 'success')),
  source_table text,
  source_id uuid,
  is_read boolean not null default false,
  created_at timestamptz not null default timezone('utc', now())
);

create index idx_notification_inbox_user_id on public.notification_inbox(user_id, created_at desc);

-- RLS for notification_inbox
alter table public.notification_inbox enable row level security;
create policy notification_inbox_select on public.notification_inbox 
  for select using (auth.uid() = user_id);
create policy notification_inbox_update on public.notification_inbox 
  for update using (auth.uid() = user_id);
create policy notification_inbox_delete on public.notification_inbox 
  for delete using (auth.uid() = user_id);

-- 2. Create emergency_access_log table
create table if not exists public.emergency_access_log (
  id uuid primary key default gen_random_uuid(),
  patient_user_id uuid not null references public.profiles(id) on delete cascade,
  accessed_by uuid references public.profiles(id) on delete set null,
  source text not null default 'in_app',
  created_at timestamptz not null default timezone('utc', now())
);

create index idx_emergency_access_patient on public.emergency_access_log(patient_user_id, created_at desc);

-- RLS for emergency_access_log
alter table public.emergency_access_log enable row level security;
-- Owner can see who accessed their ID
create policy emergency_access_log_select on public.emergency_access_log
  for select using (auth.uid() = patient_user_id);
-- Anyone authenticated can insert a log (since family members access it)
create policy emergency_access_log_insert on public.emergency_access_log
  for insert with check (true);

-- 3. Add administered_by to medicine_logs
alter table public.medicine_logs 
  add column if not exists administered_by uuid references public.profiles(id) on delete set null;

-- 4. RPC for notification_inbox (Optional Helper)
create or replace function rpc_create_notification_inbox_entry(
  p_user_id uuid,
  p_category text,
  p_title text,
  p_body text,
  p_severity text,
  p_source_table text default null,
  p_source_id uuid default null
) returns void as $$
begin
  insert into public.notification_inbox(user_id, category, title, body, severity, source_table, source_id)
  values (p_user_id, p_category, p_title, p_body, p_severity, p_source_table, p_source_id);
end;
$$ language plpgsql security definer;
