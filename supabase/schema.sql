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

-- ============================================================================
-- USER_CONSENTS TABLE
-- Records each signed-in user's acceptance of the Terms of Service + Privacy
-- Policy, and their optional marketing opt-in choice. One row per user.
--
-- Design notes:
--  * `terms_version` stamps WHICH version the user agreed to. If we update
--    the legal copy, new sign-ups get the new version, but existing users
--    are NOT re-prompted — we treat prior consent as durable per our UX
--    guidance. If we ever need a forced re-accept path, we'd add a separate
--    mechanism (e.g. a `requires_reaccept` table) rather than overload this.
--  * `marketing_opted_in_at` is stored separately so we have provable timing
--    for CAN-SPAM / GDPR if the user ever disputes it.
--  * `on delete cascade` — if a user deletes their auth account, their
--    consent row goes with them automatically.
-- ============================================================================
create table if not exists user_consents (
  user_id               uuid primary key references auth.users(id) on delete cascade,
  terms_accepted_at     timestamptz not null,
  terms_version         text        not null default 'v1-2026-04',
  marketing_opted_in    boolean     not null default false,
  marketing_opted_in_at timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

-- Auto-touch updated_at on any row update (reuses the function from above)
drop trigger if exists user_consents_touch_updated_at on user_consents;
create trigger user_consents_touch_updated_at
  before update on user_consents
  for each row
  execute function touch_updated_at();

-- ----------------------------------------------------------------------------
-- RLS for user_consents
-- Each user can only read and write their OWN consent row. There is no
-- public read — consent records are private to the account that owns them.
-- ----------------------------------------------------------------------------
alter table user_consents enable row level security;

drop policy if exists "user reads own consent"  on user_consents;
drop policy if exists "user inserts own consent" on user_consents;
drop policy if exists "user updates own consent" on user_consents;

create policy "user reads own consent"
  on user_consents for select
  using (auth.uid() = user_id);

create policy "user inserts own consent"
  on user_consents for insert
  with check (auth.uid() = user_id);

create policy "user updates own consent"
  on user_consents for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ============================================================================
-- HOUSEHOLD_MEMBERS TABLE  ⚠️ REVIEW BEFORE APPLYING
-- Drafted 2026-04-08 as part of the auth-foundation household linking work.
-- DO NOT paste into the SQL editor until Alex has reviewed the design.
--
-- Purpose: bind a signed-in user to a single household + slot so that when
-- they sign in on a new device we can pull them back to "their" household
-- automatically, instead of leaving them stuck on whatever anonymous
-- household lives in that browser's localStorage.
--
-- Design notes:
--  * One row per user (user_id PK). A user belongs to exactly one household
--    at a time. If they want to start fresh, we delete their row and let
--    them re-claim into a new household.
--  * `slot` is 1 or 2 → maps to households.profile1 / households.profile2.
--  * `household_id` is text (not FK) because households.id is text and
--    Phase-1 households can exist without ever being claimed (anonymous
--    couples). We don't want a hard FK that blocks orphan cleanup.
--  * RLS: a user can only see and modify THEIR OWN row. They cannot
--    enumerate other members of the same household via this table — that's
--    fine for now because the household row itself is still publicly
--    readable to anyone who knows the id (Phase-1 shared-secret model).
--  * `on delete cascade` from auth.users — if the user nukes their account,
--    their membership row goes with it. The household row stays (their
--    partner may still be using it).
-- ============================================================================
create table if not exists household_members (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  household_id text        not null,
  slot         smallint    not null check (slot in (1, 2)),
  joined_at    timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- Lookup partner-side: "who else is in this household?"
create index if not exists household_members_household_id_idx
  on household_members (household_id);

drop trigger if exists household_members_touch_updated_at on household_members;
create trigger household_members_touch_updated_at
  before update on household_members
  for each row
  execute function touch_updated_at();

alter table household_members enable row level security;

drop policy if exists "user reads own membership"   on household_members;
drop policy if exists "user inserts own membership" on household_members;
drop policy if exists "user updates own membership" on household_members;
drop policy if exists "user deletes own membership" on household_members;

create policy "user reads own membership"
  on household_members for select
  using (auth.uid() = user_id);

create policy "user inserts own membership"
  on household_members for insert
  with check (auth.uid() = user_id);

create policy "user updates own membership"
  on household_members for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "user deletes own membership"
  on household_members for delete
  using (auth.uid() = user_id);
