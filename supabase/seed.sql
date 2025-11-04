-- Development seed data
-- After you sign up local users (via GoTrue / Auth UI / API),
-- update the emails below to match your test accounts:

-- Note: You'll need to create test users first through Supabase Auth
-- Then update these emails to match your test user emails

-- Example: Mark one user as attending + admin
-- Replace 'attending@example.com' with your actual test user email
insert into public.memberships (user_id, institution_id, role)
select u.id, i.id, 'attending'
from auth.users u
cross join public.institutions i
where lower(u.email) = lower('attending@example.com')
on conflict (user_id, institution_id) do update set role = excluded.role;

-- Add admin role to the same user
insert into public.memberships (user_id, institution_id, role)
select u.id, i.id, 'admin'
from auth.users u
cross join public.institutions i
where lower(u.email) = lower('attending@example.com')
on conflict (user_id, institution_id) do update set role = excluded.role;

-- Example: Mark one user as fellow
-- Replace 'fellow@example.com' with your actual test user email
insert into public.memberships (user_id, institution_id, role)
select u.id, i.id, 'fellow'
from auth.users u
cross join public.institutions i
where lower(u.email) = lower('fellow@example.com')
on conflict (user_id, institution_id) do update set role = excluded.role;

-- Note: You'll need to create at least one institution first
-- Example institution creation (run manually or add to a migration):
-- insert into public.institutions (slug, name, settings)
-- values ('test-institution', 'Test Institution', '{}'::jsonb)
-- on conflict (slug) do nothing;

