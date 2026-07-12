-- supabase/migrations/20260621015000_family_task_comments_policies.sql

drop policy if exists family_task_comments_select on public.family_task_comments;
create policy family_task_comments_select
on public.family_task_comments
for select
using (
  exists (
    select 1 from public.family_tasks t
    where t.id = family_task_comments.task_id
      and public.is_family_group_member(t.group_id)
  )
);

drop policy if exists family_task_comments_insert on public.family_task_comments;
create policy family_task_comments_insert
on public.family_task_comments
for insert
with check (
  exists (
    select 1 from public.family_tasks t
    where t.id = family_task_comments.task_id
      and public.is_family_group_member(t.group_id)
  )
);
