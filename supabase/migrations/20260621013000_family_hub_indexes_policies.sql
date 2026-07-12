-- supabase/migrations/20260621013000_family_hub_indexes_policies.sql
create index if not exists idx_family_members_group_status
  on public.family_members(group_id, status);

create index if not exists idx_family_members_user_group
  on public.family_members(user_id, group_id);

create index if not exists idx_family_tasks_group_status_due
  on public.family_tasks(group_id, status, due_at desc);

create index if not exists idx_family_tasks_patient_status
  on public.family_tasks(patient_user_id, status);

create index if not exists idx_family_updates_group_created
  on public.family_updates(group_id, created_at desc);

create index if not exists idx_family_alerts_recipient_status
  on public.family_alerts(recipient_user_id, status, created_at desc);

create index if not exists idx_family_events_group_start
  on public.family_events(group_id, start_at asc);

alter table public.medical_profiles enable row level security;
alter table public.family_alert_rules enable row level security;
alter table public.family_tasks enable row level security;
alter table public.family_task_comments enable row level security;
alter table public.family_updates enable row level security;
alter table public.family_events enable row level security;
alter table public.family_alerts enable row level security;

create policy if not exists medical_profiles_select
on public.medical_profiles
for select
using (
  auth.uid() = user_id
  or exists (
    select 1 from public.family_members fm
    where fm.user_id = auth.uid()
      and fm.status = 'approved'
      and fm.can_view_emergency = true
      and fm.group_id in (
        select fm2.group_id
        from public.family_members fm2
        where fm2.user_id = medical_profiles.user_id
      )
  )
);

create policy if not exists family_tasks_select
on public.family_tasks
for select
using (public.is_family_group_member(group_id));

create policy if not exists family_tasks_insert
on public.family_tasks
for insert
with check (public.is_family_group_member(group_id));

create policy if not exists family_tasks_update
on public.family_tasks
for update
using (public.is_family_group_member(group_id))
with check (public.is_family_group_member(group_id));

create policy if not exists family_updates_select
on public.family_updates
for select
using (public.is_family_group_member(group_id));

create policy if not exists family_updates_insert
on public.family_updates
for insert
with check (public.is_family_group_member(group_id));

create policy if not exists family_events_select
on public.family_events
for select
using (public.is_family_group_member(group_id));

create policy if not exists family_events_insert
on public.family_events
for insert
with check (public.is_family_group_member(group_id));

create policy if not exists family_alerts_select
on public.family_alerts
for select
using (recipient_user_id = auth.uid() or public.is_family_group_admin(group_id));

create policy if not exists family_alerts_update
on public.family_alerts
for update
using (recipient_user_id = auth.uid() or public.is_family_group_admin(group_id))
with check (recipient_user_id = auth.uid() or public.is_family_group_admin(group_id));

create policy if not exists family_alert_rules_select
on public.family_alert_rules
for select
using (public.is_family_group_member(group_id));

create policy if not exists family_alert_rules_manage
on public.family_alert_rules
for all
using (public.is_family_group_admin(group_id))
with check (public.is_family_group_admin(group_id));
