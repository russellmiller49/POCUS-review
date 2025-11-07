-- Allow end users to create and manage their own profile row.
-- Signup currently fails when the app upserts into public.profiles because
-- there was no policy permitting inserts/updates for authenticated callers.

alter table public.profiles enable row level security;

-- Users can read their own profile (needed for future profile views, too).
drop policy if exists "users read own profile" on public.profiles;
create policy "users read own profile"
on public.profiles
for select
to authenticated
using (id = auth.uid());

-- Users can insert their own profile row during signup.
drop policy if exists "users insert own profile" on public.profiles;
create policy "users insert own profile"
on public.profiles
for insert
to authenticated
with check (id = auth.uid());

-- Users can update their own profile fields later if we expose UI.
drop policy if exists "users update own profile" on public.profiles;
create policy "users update own profile"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());
