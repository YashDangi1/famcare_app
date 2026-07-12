-- supabase/migrations/20260625000010_tighten_medical_profile_write_rules.sql

alter table public.family_members
add column if not exists can_edit_emergency boolean default false;

-- Drop existing update policies on medical_profiles if any exist with common names
drop policy if exists "Users can update their own medical profile" on public.medical_profiles;
drop policy if exists "Family members can update medical profile" on public.medical_profiles;
drop policy if exists "medical_profiles_update" on public.medical_profiles;
drop policy if exists "Users and caregivers can update medical profile" on public.medical_profiles;

-- Create explicit tightened update policy
create policy "medical_profiles_update_policy" on public.medical_profiles
for update
using (
  auth.uid() = user_id
  or exists (
    select 1
    from public.family_members my_fm
    join public.family_members patient_fm on my_fm.group_id = patient_fm.group_id
    where my_fm.user_id = auth.uid()
      and patient_fm.user_id = public.medical_profiles.user_id
      and my_fm.status = 'approved'
      and (my_fm.can_edit_emergency = true or my_fm.role = 'admin')
  )
)
with check (
  auth.uid() = user_id
  or exists (
    select 1
    from public.family_members my_fm
    join public.family_members patient_fm on my_fm.group_id = patient_fm.group_id
    where my_fm.user_id = auth.uid()
      and patient_fm.user_id = public.medical_profiles.user_id
      and my_fm.status = 'approved'
      and (my_fm.can_edit_emergency = true or my_fm.role = 'admin')
  )
);
