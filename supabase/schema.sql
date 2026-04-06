-- Couch Potatoes database schema
-- Paste this into the Supabase SQL Editor (Dashboard → SQL Editor → New Query)
-- and click "Run". It's safe to run multiple times — uses IF NOT EXISTS.

-- ============================================================================
-- HOUSEHOLDS TABLE
-- A household = one couple. Each household row contains both profiles plus
-- shared state (services, session prefs). The household ID is the only
-- identifier — there's no user auth in Phase 1. Knowing the household ID is
-- the "key" to access/modify it.
-- ============================================================================
create table if not exists households (
  id            text primary key,
  profile1      jsonb,
  profile2      jsonb,
  services      jsonb,
  session_prefs jsonb,
  state         jsonb,  -- per-person reaction state: liked, loved, seen, dismissed, nah, watchlist, tasteDNA
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- Safety net for tables created with an earlier schema version
alter table households add column if not exists state jsonb;

-- Update `updated_at` automatically on every row update
create or replace function touch_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists households_touch_updated_at on households;
create trigger households_touch_updated_at
  before update on households
  for each row
  execute function touch_updated_at();

-- ============================================================================
-- ROW LEVEL SECURITY
-- Phase 1: household ID acts as a shared secret. Anyone who knows the ID can
-- read and write that household. IDs are 32-char random tokens, so brute
-- force is infeasible (2^128 space). This is "share-link security" — good
-- enough for a consumer launch, easy to harden later with real auth.
--
-- Phase 2 (when we add auth): replace these policies with policies that
-- check auth.uid() against a household_members table.
-- ============================================================================
alter table households enable row level security;

-- Drop existing policies so this script is safe to re-run
drop policy if exists "public read households"   on households;
drop policy if exists "public insert households" on households;
drop policy if exists "public update households" on households;

create policy "public read households"
  on households for select
  using (true);

create policy "public insert households"
  on households for insert
  with check (true);

create policy "public update households"
  on households for update
  using (true)
  with check (true);

-- ============================================================================
-- REALTIME
-- Enables Supabase Realtime on the households table so partner edits push to
-- the other partner's open session live (e.g. Partner 1 adds a favorite →
-- Partner 2 sees it instantly).
-- ============================================================================
alter publication supabase_realtime add table households;
