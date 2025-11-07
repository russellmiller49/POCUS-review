-- Allow onboarding users to load institution metadata during signup/login.
-- Previously, the "read own institution" policy required the caller to
-- already belong to an institution, which meant unauthenticated (anon role)
-- clients could never fetch the list. That manifested in the app as the
-- institution picker showing an infinite spinner.

-- Relax the SELECT policy so both anon (pre-auth) and authenticated users
-- can read the institution directory. Admin/management policies remain intact.
drop policy if exists "read own institution" on public.institutions;

create policy "public read institutions"
on public.institutions
for select
to public
using (true);
