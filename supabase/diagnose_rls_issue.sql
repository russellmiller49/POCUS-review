-- Diagnose RLS Issue for User
-- Run this in Supabase SQL Editor to check why study creation is failing

-- ============================================
-- Step 1: Verify your membership exists
-- ============================================
SELECT 
    'Your Membership' as check_type,
    m.user_id,
    m.institution_id,
    i.name as institution_name,
    m.role,
    m.roles,
    m.role_approved,
    m.pgy_year,
    m.created_at
FROM public.memberships m
JOIN public.institutions i ON i.id = m.institution_id
WHERE m.user_id = 'db9d49e5-10bb-49d1-ae0d-63893b84e308'::uuid;

-- ============================================
-- Step 2: Check what auth.uid() returns
-- ============================================
SELECT 
    'Current Auth User' as check_type,
    auth.uid() as current_user_id,
    CASE 
        WHEN auth.uid() = 'db9d49e5-10bb-49d1-ae0d-63893b84e308'::uuid 
        THEN 'MATCH - Membership should work'
        ELSE 'MISMATCH - This is the problem!'
    END as status;

-- ============================================
-- Step 3: Test the RLS helper functions
-- ============================================
SELECT 
    'RLS Function Tests' as check_type,
    public.is_member_of('fd5043e9-9268-4b82-a703-88b18c8c0fd0'::uuid) as is_member_result,
    public.has_role('fd5043e9-9268-4b82-a703-88b18c8c0fd0'::uuid, 'fellow') as has_fellow_role,
    public.has_admin_role() as is_admin;

-- ============================================
-- Step 4: Check if institution exists
-- ============================================
SELECT 
    'Institution Check' as check_type,
    id,
    slug,
    name
FROM public.institutions
WHERE id = 'fd5043e9-9268-4b82-a703-88b18c8c0fd0'::uuid;

-- ============================================
-- Step 5: Test study creation policy directly
-- ============================================
-- This simulates what happens when you try to create a study
SELECT 
    'Policy Test' as check_type,
    auth.uid() = auth.uid() as created_by_check,  -- Should be true
    public.is_member_of('fd5043e9-9268-4b82-a703-88b18c8c0fd0'::uuid) as is_member_check,  -- Should be true
    CASE 
        WHEN auth.uid() = auth.uid() 
             AND public.is_member_of('fd5043e9-9268-4b82-a703-88b18c8c0fd0'::uuid)
        THEN 'POLICY SHOULD PASS - Study creation should work'
        ELSE 'POLICY WILL FAIL - Check the functions above'
    END as policy_result;

-- ============================================
-- Step 6: If auth.uid() doesn't match, update membership
-- ============================================
-- Only run this if Step 2 shows a mismatch!
-- UPDATE public.memberships
-- SET user_id = auth.uid()
-- WHERE user_id = 'db9d49e5-10bb-49d1-ae0d-63893b84e308'::uuid
--   AND institution_id = 'fd5043e9-9268-4b82-a703-88b18c8c0fd0'::uuid;

