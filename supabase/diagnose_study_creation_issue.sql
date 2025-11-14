-- Diagnostic queries to troubleshoot study creation RLS policy violation

-- 1. Check current user's memberships and approval status
SELECT 
    m.user_id,
    m.institution_id,
    i.name as institution_name,
    m.role,
    m.roles,
    m.role_approved,
    m.role_requested_at,
    m.created_at
FROM public.memberships m
JOIN public.institutions i ON i.id = m.institution_id
WHERE m.user_id = auth.uid()
ORDER BY m.created_at DESC;

-- 2. Test if is_member_of works for each institution
SELECT 
    i.id as institution_id,
    i.name as institution_name,
    public.is_member_of(i.id) as is_member,
    public.has_role(i.id, 'fellow') as has_fellow_role,
    public.has_admin_role() as is_admin
FROM public.institutions i
ORDER BY i.name;

-- 3. Check what the current INSERT policy actually requires
-- (This shows the policy definition)
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'studies' AND cmd = 'INSERT';

-- 4. Simulate the policy check for a specific institution
-- Replace 'INSTITUTION_ID_HERE' with the actual institution_id you're trying to use
SELECT 
    auth.uid() as current_user_id,
    'INSTITUTION_ID_HERE'::uuid as institution_id,
    auth.uid() = auth.uid() as created_by_check,
    public.is_member_of('INSTITUTION_ID_HERE'::uuid) as is_member_check,
    (auth.uid() = auth.uid() AND public.is_member_of('INSTITUTION_ID_HERE'::uuid)) as policy_passes;

-- 5. Check if there are multiple INSERT policies (which could cause conflicts)
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'studies' AND cmd = 'INSERT';













