-- Limitless Lifting — Supabase schema
-- Run this in the Supabase SQL editor once after creating your project.

create extension if not exists "uuid-ossp";

-- ── Profiles ──────────────────────────────────────────────
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  name text not null,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Users can view own profile"
  on public.profiles for select using (auth.uid() = id);

create policy "Users can insert own profile"
  on public.profiles for insert with check (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update using (auth.uid() = id);

-- ── Routines (workout plans) ──────────────────────────────
create table if not exists public.routines (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users on delete cascade,
  name text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.routines enable row level security;

create policy "Users can view own routines"
  on public.routines for select using (auth.uid() = user_id);

create policy "Users can insert own routines"
  on public.routines for insert with check (auth.uid() = user_id);

create policy "Users can update own routines"
  on public.routines for update using (auth.uid() = user_id);

create policy "Users can delete own routines"
  on public.routines for delete using (auth.uid() = user_id);

-- ── Exercises ────────────────────────────────────────────
create table if not exists public.exercises (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users on delete cascade,
  name text not null,
  muscle_group text,
  equipment text,
  instructions text,
  media_url text,
  is_custom boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.exercises enable row level security;

create policy "Users can view own exercises"
  on public.exercises for select using (auth.uid() = user_id);

create policy "Users can insert own exercises"
  on public.exercises for insert with check (auth.uid() = user_id);

create policy "Users can update own exercises"
  on public.exercises for update using (auth.uid() = user_id);

create policy "Users can delete own exercises"
  on public.exercises for delete using (auth.uid() = user_id);

-- ── Workouts (sessions) ──────────────────────────────────
create table if not exists public.workouts (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users on delete cascade,
  routine_id uuid references public.routines on delete set null,
  name text,
  date date not null default current_date,
  duration_minutes integer,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.workouts enable row level security;

create policy "Users can view own workouts"
  on public.workouts for select using (auth.uid() = user_id);

create policy "Users can insert own workouts"
  on public.workouts for insert with check (auth.uid() = user_id);

create policy "Users can update own workouts"
  on public.workouts for update using (auth.uid() = user_id);

create policy "Users can delete own workouts"
  on public.workouts for delete using (auth.uid() = user_id);

-- ── Workout sets ─────────────────────────────────────────
create table if not exists public.workout_sets (
  id uuid primary key default uuid_generate_v4(),
  workout_id uuid not null references public.workouts on delete cascade,
  exercise_id uuid references public.exercises on delete set null,
  set_number integer not null default 1,
  reps integer not null default 0,
  weight numeric(8,2) not null default 0,
  completed boolean not null default false,
  rest_seconds integer,
  created_at timestamptz not null default now()
);

alter table public.workout_sets enable row level security;

create policy "Users can view own workout sets"
  on public.workout_sets for select using (
    exists (
      select 1 from public.workouts w
      where w.id = workout_sets.workout_id and w.user_id = auth.uid()
    )
  );

create policy "Users can insert own workout sets"
  on public.workout_sets for insert with check (
    exists (
      select 1 from public.workouts w
      where w.id = workout_sets.workout_id and w.user_id = auth.uid()
    )
  );

create policy "Users can update own workout sets"
  on public.workout_sets for update using (
    exists (
      select 1 from public.workouts w
      where w.id = workout_sets.workout_id and w.user_id = auth.uid()
    )
  );

create policy "Users can delete own workout sets"
  on public.workout_sets for delete using (
    exists (
      select 1 from public.workouts w
      where w.id = workout_sets.workout_id and w.user_id = auth.uid()
    )
  );

-- ── Weigh-ins (body weight tracking) ─────────────────────
create table if not exists public.weigh_ins (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users on delete cascade,
  weight numeric(8,2) not null,
  date date not null default current_date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.weigh_ins enable row level security;

create policy "Users can view own weigh-ins"
  on public.weigh_ins for select using (auth.uid() = user_id);

create policy "Users can insert own weigh-ins"
  on public.weigh_ins for insert with check (auth.uid() = user_id);

create policy "Users can update own weigh-ins"
  on public.weigh_ins for update using (auth.uid() = user_id);

create policy "Users can delete own weigh-ins"
  on public.weigh_ins for delete using (auth.uid() = user_id);

-- ── Push subscriptions ───────────────────────────────────
create table if not exists public.push_subscriptions (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users on delete cascade,
  endpoint text not null,
  keys jsonb not null,
  device_id text,
  created_at timestamptz not null default now()
);

alter table public.push_subscriptions enable row level security;

create policy "Users can view own push subscriptions"
  on public.push_subscriptions for select using (auth.uid() = user_id);

create policy "Users can insert own push subscriptions"
  on public.push_subscriptions for insert with check (auth.uid() = user_id);

create policy "Users can delete own push subscriptions"
  on public.push_subscriptions for delete using (auth.uid() = user_id);

-- ── Profile auto-creation trigger ─────────────────────────
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, name)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();