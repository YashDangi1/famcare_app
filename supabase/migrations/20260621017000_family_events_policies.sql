-- supabase/migrations/20260621017000_family_events_policies.sql

drop policy if exists family_events_update on public.family_events;
create policy family_events_update
on public.family_events
for update
using (public.is_family_group_member(group_id));

drop policy if exists family_events_delete on public.family_events;
create policy family_events_delete
on public.family_events
for delete
using (public.is_family_group_member(group_id));
