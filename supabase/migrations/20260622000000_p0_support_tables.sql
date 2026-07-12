-- supabase/migrations/20260622000000_p0_support_tables.sql

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  category text not null,
  subject text not null,
  message text not null,
  status text not null default 'open' check (status in ('open', 'in_progress', 'resolved', 'closed')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.app_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  rating integer check (rating >= 1 and rating <= 5),
  screen text,
  message text not null,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

-- RLS for support_tickets
alter table public.support_tickets enable row level security;
create policy support_tickets_select on public.support_tickets for select using (auth.uid() = user_id);
create policy support_tickets_insert on public.support_tickets for insert with check (auth.uid() = user_id);
create policy support_tickets_update on public.support_tickets for update using (auth.uid() = user_id);

-- RLS for app_feedback
alter table public.app_feedback enable row level security;
create policy app_feedback_select on public.app_feedback for select using (auth.uid() = user_id);
create policy app_feedback_insert on public.app_feedback for insert with check (auth.uid() = user_id);

-- Triggers for updated_at
drop trigger if exists trg_support_tickets_updated_at on public.support_tickets;
create trigger trg_support_tickets_updated_at
before update on public.support_tickets
for each row execute function public.set_updated_at();
