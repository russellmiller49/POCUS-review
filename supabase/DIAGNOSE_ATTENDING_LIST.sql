-- ============================================
-- DIAGNOSE ATTENDING LIST ISSUE
-- This script checks why new attendings don't appear in the list
-- ============================================

-- STEP 1: Check all memberships with attending role
SELECT
  m.user_id,
  u.email,
  m.institution_id,
  i.name as institution_name,
  m.role,
  m.roles,
  m.role_approved,
  m.role_requested_at,
  m.created_at,
  CASE 
    WHEN p.id IS NULL THEN '❌ MISSING PROFILE'
    ELSE '✅ Has Profile'
  END as profile_status,
  CASE
    WHEN m.role_approved = false THEN '❌ NOT APPROVED'
    WHEN m.role_approved = true THEN '✅ APPROVED'
    WHEN m.role_approved IS NULL THEN '✅ NULL (treated as approved)'
    ELSE '⚠️ UNKNOWN'
  END as approval_status
FROM public.memberships m
LEFT JOIN auth.users u ON u.id = m.user_id
LEFT JOIN public.institutions i ON i.id = m.institution_id
LEFT JOIN public.profiles p ON p.id = m.user_id
WHERE m.role = 'attending' OR 'attending' = ANY(m.roles)
ORDER BY m.created_at DESC;

-- STEP 2: Check what the list_institution_members function would return
-- (This simulates what the app sees)
SELECT
  'Function Output' as check_type,
  COUNT(*) as attending_count
FROM public.memberships m
JOIN public.profiles p ON p.id = m.user_id
WHERE (m.role = 'attending' OR 'attending' = ANY(m.roles))
  AND COALESCE(m.role_approved, true) = true;

-- STEP 3: Find memberships missing profiles
SELECT
  m.user_id,
  u.email,
  i.name as institution_name,
  m.role,
  m.roles,
  '❌ MISSING PROFILE - This is why they don''t appear!' as issue
FROM public.memberships m
LEFT JOIN auth.users u ON u.id = m.user_id
LEFT JOIN public.institutions i ON i.id = m.institution_id
LEFT JOIN public.profiles p ON p.id = m.user_id
WHERE (m.role = 'attending' OR 'attending' = ANY(m.roles))
  AND p.id IS NULL;

-- STEP 4: Find memberships not approved
SELECT
  m.user_id,
  u.email,
  i.name as institution_name,
  m.role,
  m.roles,
  m.role_approved,
  '❌ NOT APPROVED - This is why they don''t appear!' as issue
FROM public.memberships m
LEFT JOIN auth.users u ON u.id = m.user_id
LEFT JOIN public.institutions i ON i.id = m.institution_id
LEFT JOIN public.profiles p ON p.id = m.user_id
WHERE (m.role = 'attending' OR 'attending' = ANY(m.roles))
  AND COALESCE(m.role_approved, true) = false;

-- ============================================
-- FIXES (Uncomment and run as needed)
-- ============================================

-- FIX 1: Create missing profiles for users who have memberships but no profile
/*
INSERT INTO public.profiles (id, email, full_name)
SELECT 
  u.id,
  u.email,
  COALESCE(u.raw_user_meta_data->>'full_name', u.email) as full_name
FROM auth.users u
INNER JOIN public.memberships m ON m.user_id = u.id
LEFT JOIN public.profiles p ON p.id = u.id
WHERE p.id IS NULL
ON CONFLICT (id) DO NOTHING;
*/

-- FIX 2: Approve pending attendings
/*
UPDATE public.memberships
SET 
  role_approved = true,
  updated_at = now()
WHERE (role = 'attending' OR 'attending' = ANY(roles))
  AND (role_approved = false OR role_approved IS NULL);
*/

-- FIX 3: Combined fix - Create profiles AND approve attendings
/*
-- Create missing profiles
INSERT INTO public.profiles (id, email, full_name)
SELECT 
  u.id,
  u.email,
  COALESCE(u.raw_user_meta_data->>'full_name', u.email) as full_name
FROM auth.users u
INNER JOIN public.memberships m ON m.user_id = u.id
LEFT JOIN public.profiles p ON p.id = u.id
WHERE p.id IS NULL
ON CONFLICT (id) DO UPDATE
SET email = EXCLUDED.email,
    full_name = COALESCE(profiles.full_name, EXCLUDED.full_name);

-- Approve pending attendings
UPDATE public.memberships
SET 
  role_approved = true,
  updated_at = now()
WHERE (role = 'attending' OR 'attending' = ANY(roles))
  AND (role_approved = false OR role_approved IS NULL);
*/

-- STEP 5: Verify the fix worked
/*
SELECT
  m.user_id,
  u.email,
  i.name as institution_name,
  m.role,
  m.roles,
  m.role_approved,
  CASE 
    WHEN p.id IS NULL THEN '❌ STILL MISSING PROFILE'
    ELSE '✅ Has Profile'
  END as profile_status,
  CASE
    WHEN COALESCE(m.role_approved, true) = false THEN '❌ STILL NOT APPROVED'
    ELSE '✅ Approved'
  END as approval_status
FROM public.memberships m
LEFT JOIN auth.users u ON u.id = m.user_id
LEFT JOIN public.institutions i ON i.id = m.institution_id
LEFT JOIN public.profiles p ON p.id = m.user_id
WHERE m.role = 'attending' OR 'attending' = ANY(m.roles)
ORDER BY m.created_at DESC;
*/

