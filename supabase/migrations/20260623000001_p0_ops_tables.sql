-- supabase/migrations/20260623000001_p0_ops_tables.sql

create table if not exists public.crash_logs (
    id uuid default gen_random_uuid() primary key,
    user_id uuid references auth.users(id) on delete set null,
    error_message text not null,
    stack_trace text,
    device_info jsonb,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table if not exists public.analytics_events (
    id uuid default gen_random_uuid() primary key,
    user_id uuid references auth.users(id) on delete set null,
    event_name text not null,
    payload jsonb,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Row Level Security (RLS)
alter table public.crash_logs enable row level security;
alter table public.analytics_events enable row level security;

-- Policies: Users can only insert their own logs/events
create policy "Users can insert their own crash logs" on public.crash_logs for insert with check (auth.uid() = user_id or auth.uid() is null);
create policy "Users can insert their own analytics events" on public.analytics_events for insert with check (auth.uid() = user_id or auth.uid() is null);

-- Select policies: Only admins (or nobody from client) can read logs, but for now we'll allow users to read their own
create policy "Users can read own crash logs" on public.crash_logs for select using (auth.uid() = user_id);
create policy "Users can read own analytics events" on public.analytics_events for select using (auth.uid() = user_id);
