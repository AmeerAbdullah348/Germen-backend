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

-- One row per (user, item type, item id): SM-2 state for non-vocab content
-- (grammar, and later listening/reading/writing). Kept as a separate table
-- from word_progress rather than merging them — zero migration risk to
-- existing vocab progress, same SM-2 field shape reused as-is.
create table if not exists public.item_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  item_type text not null,
  item_id text not null,
  repetitions integer not null default 0,
  ease_factor numeric not null default 2.5,
  interval_days integer not null default 0,
  due_date timestamptz not null default now(),
  last_result text,
  updated_at timestamptz not null default now(),
  primary key (user_id, item_type, item_id)
);

alter table public.item_progress enable row level security;

create policy "Users can view own item progress" on public.item_progress
  for select using (auth.uid() = user_id);
create policy "Users can insert own item progress" on public.item_progress
  for insert with check (auth.uid() = user_id);
create policy "Users can update own item progress" on public.item_progress
  for update using (auth.uid() = user_id);

-- Append-only log of wrong answers, generic across content types, so the
-- Mistakes page can show "you answered X, correct was Y" and let the user
-- practice flagged items again. Never updated after insert.
create table if not exists public.mistakes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_type text not null,
  item_id text not null,
  unit_or_topic_id text,
  user_answer text,
  correct_answer text,
  created_at timestamptz not null default now()
);

alter table public.mistakes enable row level security;

create policy "Users can view own mistakes" on public.mistakes
  for select using (auth.uid() = user_id);
create policy "Users can insert own mistakes" on public.mistakes
  for insert with check (auth.uid() = user_id);

-- One row per (user, achievement): unlocked badges. achievement_id matches
-- a static id in a frontend achievements catalog (not built yet — table
-- shape is low-risk enough to add now so later phases don't need a migration).
create table if not exists public.achievements (
  user_id uuid not null references auth.users(id) on delete cascade,
  achievement_id text not null,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, achievement_id)
);

alter table public.achievements enable row level security;

create policy "Users can view own achievements" on public.achievements
  for select using (auth.uid() = user_id);
create policy "Users can insert own achievements" on public.achievements
  for insert with check (auth.uid() = user_id);

-- One row per placement test attempt: estimated CEFR level + raw per-section
-- scores. Purely a recommendation record — never auto-mutates word_progress
-- or item_progress, so retaking it can't destroy existing progress.
create table if not exists public.placement_results (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  estimated_level text not null,
  raw_scores jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.placement_results enable row level security;

create policy "Users can view own placement results" on public.placement_results
  for select using (auth.uid() = user_id);
create policy "Users can insert own placement results" on public.placement_results
  for insert with check (auth.uid() = user_id);
