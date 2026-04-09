-- Couch Potatoes: household_members migration
-- Paste into Supabase Dashboard → SQL Editor → New Query → Run
-- Safe to run multiple times (uses IF NOT EXISTS, drops before recreating)

create table if not exists household_members (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  household_id text        not null,
  slot         smallint    not null check (slot in (1, 2)),
  joined_at    timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- Lookup: "who else is in this household?"
create index if not exists household_members_household_id_idx
  on household_members (household_id);

-- Auto-touch updated_at (reuses existing function from households schema)
drop trigger if exists household_members_touch_updated_at on household_members;
create trigger household_members_touch_updated_at
  before update on household_members
  for each row
  execute function touch_updated_at();

-- RLS: user can only see/modify their own row
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
