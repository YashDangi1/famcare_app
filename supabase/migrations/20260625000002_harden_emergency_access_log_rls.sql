-- supabase/migrations/20260625000002_harden_emergency_access_log_rls.sql

drop policy if exists emergency_access_log_insert on public.emergency_access_log;
create policy emergency_access_log_insert on public.emergency_access_log
  for insert with check (auth.uid() is not null and accessed_by = auth.uid());
