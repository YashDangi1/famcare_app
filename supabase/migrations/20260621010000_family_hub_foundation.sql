-- supabase/migrations/20260621010000_family_hub_foundation.sql
create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create or replace function public.is_family_group_member(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.family_members fm
    where fm.group_id = p_group_id
      and fm.user_id = auth.uid()
      and fm.status = 'approved'
  );
$$;

create or replace function public.is_family_group_admin(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.family_members fm
    where fm.group_id = p_group_id
      and fm.user_id = auth.uid()
      and fm.status = 'approved'
      and fm.role = 'admin'
  );
$$;

alter table public.family_members
  add column if not exists relationship_label text,
  add column if not exists is_primary_caregiver boolean not null default false,
  add column if not exists is_emergency_contact boolean not null default false,
  add column if not exists emergency_priority smallint not null default 99,
  add column if not exists can_view_meds boolean not null default true,
  add column if not exists can_edit_meds boolean not null default false,
  add column if not exists can_view_vitals boolean not null default true,
  add column if not exists can_log_vitals boolean not null default false,
  add column if not exists can_view_appointments boolean not null default true,
  add column if not exists can_manage_appointments boolean not null default false,
  add column if not exists can_view_records boolean not null default true,
  add column if not exists can_upload_records boolean not null default false,
  add column if not exists can_manage_tasks boolean not null default false,
  add column if not exists can_view_emergency boolean not null default false,
  add column if not exists notify_missed_dose boolean not null default true,
  add column if not exists notify_low_stock boolean not null default true,
  add column if not exists notify_appointments boolean not null default true,
  add column if not exists notify_vitals boolean not null default false,
  add column if not exists notify_tasks boolean not null default true,
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

create table if not exists public.medical_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  blood_group text,
  allergies text[] not null default '{}',
  conditions text[] not null default '{}',
  chronic_notes text,
  doctor_name text,
  doctor_phone text,
  hospital_name text,
  emergency_contacts jsonb not null default '[]'::jsonb,
  insurance_info jsonb not null default '{}'::jsonb,
  current_med_summary text,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.family_alert_rules (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.family_groups(id) on delete cascade,
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
  enabled boolean not null default true,
  level_1_delay_minutes integer not null default 0,
  level_2_delay_minutes integer not null default 15,
  level_3_delay_minutes integer not null default 30,
  quiet_hours_start time,
  quiet_hours_end time,
  delivery_channels jsonb not null default '["in_app","push"]'::jsonb,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (group_id, category)
);

drop trigger if exists trg_family_members_updated_at on public.family_members;
create trigger trg_family_members_updated_at
before update on public.family_members
for each row execute function public.set_updated_at();

drop trigger if exists trg_medical_profiles_updated_at on public.medical_profiles;
create trigger trg_medical_profiles_updated_at
before update on public.medical_profiles
for each row execute function public.set_updated_at();

drop trigger if exists trg_family_alert_rules_updated_at on public.family_alert_rules;
create trigger trg_family_alert_rules_updated_at
before update on public.family_alert_rules
for each row execute function public.set_updated_at();
