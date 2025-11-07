-- Diagnostic queries to debug RLS policy issues
-- Run these in Supabase SQL Editor to check why study creation is failing

-- 1. Check current authenticated user
SELECT auth.uid() as current_user_id;

-- 2. Check user's memberships
SELECT 
    m.user_id,
    m.institution_id,
    m.role,
    m.roles,
    i.name as institution_name,
    i.slug as institution_slug
FROM public.memberships m
JOIN public.institutions i ON i.id = m.institution_id
WHERE m.user_id = auth.uid();

-- 3. Check if user has 'fellow' role for a specific institution
-- Replace the UUID below with your institution_id
SELECT 
    public.has_role('YOUR_INSTITUTION_ID_HERE'::uuid, 'fellow') as has_fellow_role,
    public.has_admin_role() as has_admin_role,
    public.is_member_of('YOUR_INSTITUTION_ID_HERE'::uuid) as is_member;

-- 4. Test the RLS policy conditions manually
-- Replace values below with actual values from your app
SELECT 
    auth.uid() = 'YOUR_USER_ID_HERE'::uuid as created_by_matches,
    public.is_member_of('YOUR_INSTITUTION_ID_HERE'::uuid) as is_member,
    public.has_role('YOUR_INSTITUTION_ID_HERE'::uuid, 'fellow') as has_fellow_role,
    public.has_admin_role() as has_admin_role;

-- 5. Check all memberships (if you're admin)
SELECT * FROM public.memberships ORDER BY user_id, institution_id;

-- 6. Check all institutions
SELECT id, slug, name FROM public.institutions;



