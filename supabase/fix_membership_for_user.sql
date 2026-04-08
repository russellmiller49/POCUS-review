-- Fix Membership for Specific User
-- This ensures the membership is correctly set up for user db9d49e5-10bb-49d1-ae0d-63893b84e308

-- ============================================
-- Step 1: Ensure membership exists and is correct
-- ============================================
INSERT INTO public.memberships (
    user_id,
    institution_id,
    role,
    roles,
    role_approved,
    pgy_year,
    role_requested_at
)
VALUES (
    'db9d49e5-10bb-49d1-ae0d-63893b84e308'::uuid,
    'fd5043e9-9268-4b82-a703-88b18c8c0fd0'::uuid,
    'fellow',
    NULL,  -- roles array
    true,  -- approved
    'PGY-4',
    '2025-11-07 00:56:59.483+00'::timestamptz
)
ON CONFLICT (user_id, institution_id)
DO UPDATE SET
    role = EXCLUDED.role,
    role_approved = true,  -- Ensure it's approved
    pgy_year = EXCLUDED.pgy_year,
    updated_at = now();

-- ============================================
-- Step 2: Verify the membership (using explicit user_id)
-- ============================================
SELECT 
    m.user_id,
    m.institution_id,
    i.name as institution_name,
    i.slug as institution_slug,
    m.role,
    m.roles,
    m.role_approved,
    m.pgy_year,
    m.created_at,
    m.updated_at,
    CASE 
        WHEN m.role_approved = true THEN '✅ APPROVED - Should be able to create studies'
        WHEN m.role_approved = false THEN '❌ PENDING - Needs approval'
        ELSE '⚠️ NULL - May need to set to true'
    END as status
FROM public.memberships m
JOIN public.institutions i ON i.id = m.institution_id
WHERE m.user_id = 'db9d49e5-10bb-49d1-ae0d-63893b84e308'::uuid;

-- ============================================
-- Step 3: Test RLS functions with this user
-- ============================================
-- Note: These will use auth.uid(), so make sure you're logged in as this user
SELECT 
    'RLS Function Test' as test_name,
    public.is_member_of('fd5043e9-9268-4b82-a703-88b18c8c0fd0'::uuid) as is_member,
    public.has_role('fd5043e9-9268-4b82-a703-88b18c8c0fd0'::uuid, 'fellow') as has_fellow_role;

