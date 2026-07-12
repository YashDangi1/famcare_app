-- supabase/migrations/20260621024000_health_family_rls_policies.sql

-- Helper function to check if user has access to another user's health module
create or replace function public.can_view_health_module(p_target_user_id uuid, p_module text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.family_members fm
    where fm.user_id = auth.uid()
      and fm.status = 'approved'
      and (
        (p_module = 'vitals' and fm.can_view_vitals = true) or
        (p_module = 'records' and fm.can_view_records = true) or
        (p_module = 'appointments' and fm.can_view_appointments = true) or
        (p_module = 'symptoms' and fm.can_view_vitals = true) -- Grouping symptoms with vitals
      )
      and fm.group_id in (
        select fm2.group_id
        from public.family_members fm2
        where fm2.user_id = p_target_user_id
      )
  );
$$;

-- Symptoms Policies
drop policy if exists symptoms_select_own on public.symptoms;
create policy symptoms_select_family on public.symptoms
for select
using (auth.uid() = user_id or public.can_view_health_module(user_id, 'symptoms'));

-- Health Records Policies
drop policy if exists health_records_select_own on public.health_records;
create policy health_records_select_family on public.health_records
for select
using (auth.uid() = user_id or public.can_view_health_module(user_id, 'records'));

-- Appointments Upgrade Policies
drop policy if exists "Users can view their own appointments" on public.appointments;
create policy appointments_select_family on public.appointments
for select
using (auth.uid() = user_id or public.can_view_health_module(user_id, 'appointments'));

drop policy if exists appointment_notes_select_own on public.appointment_notes;
create policy appointment_notes_select_family on public.appointment_notes
for select
using (
  exists (
    select 1 from public.appointments a
    where a.id = appointment_id and (a.user_id = auth.uid() or public.can_view_health_module(a.user_id, 'appointments'))
  )
);

-- Health Reports Exports Policies
drop policy if exists health_report_exports_select_own on public.health_report_exports;
create policy health_report_exports_select_family on public.health_report_exports
for select
using (auth.uid() = user_id or public.can_view_health_module(user_id, 'records'));

-- Health Documents Bucket Policies
drop policy if exists "Health documents are publicly accessible." on storage.objects;
create policy "Health documents are readable by owner and family."
  on storage.objects for select
  using ( bucket_id = 'health_documents' and (auth.uid() = owner or public.can_view_health_module(owner, 'records')) );

-- Medications Policies
drop policy if exists medications_select_own on public.medications;
create policy medications_select_family on public.medications
for select
using (auth.uid() = user_id or public.can_view_health_module(user_id, 'records'));

-- Vitals Policies
drop policy if exists vitals_select_own on public.vitals;
create policy vitals_select_family on public.vitals
for select
using (auth.uid() = user_id or public.can_view_health_module(user_id, 'vitals'));
