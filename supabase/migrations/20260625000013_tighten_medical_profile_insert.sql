-- supabase/migrations/20260625000013_tighten_medical_profile_insert.sql

-- Drop existing insert policies
drop policy if exists "medical_profiles_insert" on public.medical_profiles;
drop policy if exists "Users can insert their own medical profile" on public.medical_profiles;
drop policy if exists "Family members can insert medical profile" on public.medical_profiles;
drop policy if exists "Users and caregivers can insert medical profile" on public.medical_profiles;

-- Create explicit tightened insert policy mirroring the update policy
create policy "medical_profiles_insert_policy" on public.medical_profiles
for insert
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
