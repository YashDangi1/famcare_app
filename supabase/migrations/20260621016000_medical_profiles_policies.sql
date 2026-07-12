-- supabase/migrations/20260621016000_medical_profiles_policies.sql

drop policy if exists medical_profiles_insert on public.medical_profiles;
create policy medical_profiles_insert
on public.medical_profiles
for insert
with check (
  auth.uid() = user_id
  or exists (
    select 1 from public.family_members fm
    where fm.user_id = auth.uid()
      and fm.status = 'approved'
      and fm.group_id in (
        select fm2.group_id
        from public.family_members fm2
        where fm2.user_id = medical_profiles.user_id
      )
  )
);

drop policy if exists medical_profiles_update on public.medical_profiles;
create policy medical_profiles_update
on public.medical_profiles
for update
using (
  auth.uid() = user_id
  or exists (
    select 1 from public.family_members fm
    where fm.user_id = auth.uid()
      and fm.status = 'approved'
      and fm.group_id in (
        select fm2.group_id
        from public.family_members fm2
        where fm2.user_id = medical_profiles.user_id
      )
  )
);
