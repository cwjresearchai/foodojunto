-- FoodoJunto — Supabase setup script
-- Run this once, in full, in your Supabase project's SQL Editor
-- (Dashboard → SQL Editor → New query → paste → Run).
--
-- Creates every table the app talks to, plus the two storage buckets it
-- uploads photos to. Safe to re-run: each statement guards against objects
-- that already exist.

create extension if not exists pgcrypto;

-- ── HOUSEHOLDS ──────────────────────────────────────────────
create table if not exists households (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  join_code    text not null unique,
  dinner_days  text[] not null default array['sat','sun'],
  meal_types   text[] not null default array['dinner'],
  banner_url   text,
  created_at   timestamptz not null default now()
);

create table if not exists household_members (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references households(id) on delete cascade,
  name         text not null
);

-- ── WEEKLY PLANNING ─────────────────────────────────────────
create table if not exists dinner_attendance (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references households(id) on delete cascade,
  dinner_date  date not null,
  member_name  text not null,
  response     text not null check (response in ('yes','no')),
  unique (household_id, dinner_date, member_name)
);

create table if not exists dinner_options (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references households(id) on delete cascade,
  dinner_date  date not null,
  dish_name    text not null,
  suggested_by text,
  notes        text,
  created_at   timestamptz not null default now()
);

create table if not exists dinner_votes (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references households(id) on delete cascade,
  dinner_date  date not null,
  voter_name   text not null,
  option_id    uuid not null references dinner_options(id) on delete cascade,
  unique (household_id, dinner_date, voter_name)
);

-- ── MEAL HISTORY & RATINGS ──────────────────────────────────
create table if not exists dinner_history (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references households(id) on delete cascade,
  dish_name    text not null,
  date         date not null,
  notes        text,
  photo_url    text,
  created_at   timestamptz not null default now()
);

create table if not exists meal_ratings (
  id              uuid primary key default gen_random_uuid(),
  meal_id         uuid not null references dinner_history(id) on delete cascade,
  household_id    uuid not null references households(id) on delete cascade,
  member_name     text not null,
  overall         text check (overall in ('up','neu','down')),
  taste_profiles  jsonb not null default '{}'::jsonb,
  unique (meal_id, member_name)
);

-- ── ROW LEVEL SECURITY ──────────────────────────────────────
-- FoodoJunto has no login step — a household's join code is a UI convention,
-- not a database-enforced boundary. These "allow all" policies match that
-- design: anyone holding your anon key can read/write any household's rows.
-- That's the intended trust model for a small self-hosted family app on your
-- own Supabase project. If you need real per-household isolation, you'd need
-- to add Supabase Auth and rewrite these policies around auth.uid() instead.
alter table households         enable row level security;
alter table household_members  enable row level security;
alter table dinner_attendance  enable row level security;
alter table dinner_options     enable row level security;
alter table dinner_votes       enable row level security;
alter table dinner_history     enable row level security;
alter table meal_ratings       enable row level security;

create policy "allow all" on households        for all using (true) with check (true);
create policy "allow all" on household_members for all using (true) with check (true);
create policy "allow all" on dinner_attendance  for all using (true) with check (true);
create policy "allow all" on dinner_options     for all using (true) with check (true);
create policy "allow all" on dinner_votes       for all using (true) with check (true);
create policy "allow all" on dinner_history     for all using (true) with check (true);
create policy "allow all" on meal_ratings       for all using (true) with check (true);

-- ── STORAGE (family & meal photos) ──────────────────────────
insert into storage.buckets (id, name, public)
values ('family-photos', 'family-photos', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('dinner-photos', 'dinner-photos', true)
on conflict (id) do nothing;

create policy "public read family-photos" on storage.objects
  for select using (bucket_id = 'family-photos');
create policy "anon upload family-photos" on storage.objects
  for insert with check (bucket_id = 'family-photos');

create policy "public read dinner-photos" on storage.objects
  for select using (bucket_id = 'dinner-photos');
create policy "anon upload dinner-photos" on storage.objects
  for insert with check (bucket_id = 'dinner-photos');
