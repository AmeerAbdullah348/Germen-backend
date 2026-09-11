-- Run this once in the Supabase Dashboard: Project -> SQL Editor -> New query -> paste -> Run.
-- (The anon key the app uses can't create tables — this needs to run with
-- the dashboard's elevated access.)

-- One row per user: display name + gamification stats.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default 'Learner',
  xp integer not null default 0,
  streak_count integer not null default 0,
  last_active_day date,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Users can view own profile" on public.profiles
  for select using (auth.uid() = id);
create policy "Users can insert own profile" on public.profiles
  for insert with check (auth.uid() = id);
create policy "Users can update own profile" on public.profiles
  for update using (auth.uid() = id);

-- Auto-create a profile row whenever someone signs up, using the name they
-- passed in signUp()'s options.data.name.
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, name)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', 'Learner'));
  return new;
end;
$$ language plpgsql security definer set search_path = public;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- One row per (user, word): SM-2 spaced-repetition state.
create table if not exists public.word_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  word_id text not null,
  repetitions integer not null default 0,
  ease_factor numeric not null default 2.5,
  interval_days integer not null default 0,
  due_date timestamptz not null default now(),
  last_result text,
  updated_at timestamptz not null default now(),
  primary key (user_id, word_id)
);

alter table public.word_progress enable row level security;

create policy "Users can view own word progress" on public.word_progress
  for select using (auth.uid() = user_id);
create policy "Users can insert own word progress" on public.word_progress
  for insert with check (auth.uid() = user_id);
create policy "Users can update own word progress" on public.word_progress
  for update using (auth.uid() = user_id);
