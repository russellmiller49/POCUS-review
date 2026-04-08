-- ============================================
-- FIX ATTENDING LIST - Auto-fix common issues
-- This will make new attendings appear in the list
-- ============================================

-- STEP 1: Show what we're fixing
DO $$
DECLARE
  missing_profile_count integer;
  unapproved_count integer;
BEGIN
  SELECT COUNT(*) INTO missing_profile_count
  FROM public.memberships m
  LEFT JOIN public.profiles p ON p.id = m.user_id
  WHERE (m.role = 'attending' OR 'attending' = ANY(m.roles))
    AND p.id IS NULL;
  
  SELECT COUNT(*) INTO unapproved_count
  FROM public.memberships m
  WHERE (m.role = 'attending' OR 'attending' = ANY(m.roles))
    AND COALESCE(m.role_approved, true) = false;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'FIXING ATTENDING LIST ISSUES:';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Memberships missing profiles: %', missing_profile_count;
  RAISE NOTICE 'Unapproved attendings: %', unapproved_count;
  RAISE NOTICE '========================================';
END $$;

-- STEP 2: Create missing profiles for all users with memberships
-- This ensures every user who has a membership also has a profile
INSERT INTO public.profiles (id, email, full_name)
SELECT 
  u.id,
  u.email,
  COALESCE(
    u.raw_user_meta_data->>'full_name',
    SPLIT_PART(u.email, '@', 1)  -- Use email prefix as fallback
  ) as full_name
FROM auth.users u
INNER JOIN public.memberships m ON m.user_id = u.id
LEFT JOIN public.profiles p ON p.id = u.id
WHERE p.id IS NULL
ON CONFLICT (id) DO UPDATE
SET 
  email = EXCLUDED.email,
  full_name = COALESCE(profiles.full_name, EXCLUDED.full_name);

-- STEP 3: Approve all pending attendings
-- Attendings need role_approved = true to appear in the list
UPDATE public.memberships
SET 
  role_approved = true,
  updated_at = now()
WHERE (role = 'attending' OR 'attending' = ANY(roles))
  AND (role_approved = false OR role_approved IS NULL);

-- STEP 4: Verify the fix
DO $$
DECLARE
  total_attendings integer;
  visible_attendings integer;
  missing_profile_count integer;
  unapproved_count integer;
BEGIN
  -- Count total attendings
  SELECT COUNT(*) INTO total_attendings
  FROM public.memberships m
  WHERE m.role = 'attending' OR 'attending' = ANY(m.roles);
  
  -- Count attendings that will appear in the list (have profile + approved)
  SELECT COUNT(*) INTO visible_attendings
  FROM public.memberships m
  JOIN public.profiles p ON p.id = m.user_id
  WHERE (m.role = 'attending' OR 'attending' = ANY(m.roles))
    AND COALESCE(m.role_approved, true) = true;
  
  -- Count remaining issues
  SELECT COUNT(*) INTO missing_profile_count
  FROM public.memberships m
  LEFT JOIN public.profiles p ON p.id = m.user_id
  WHERE (m.role = 'attending' OR 'attending' = ANY(m.roles))
    AND p.id IS NULL;
  
  SELECT COUNT(*) INTO unapproved_count
  FROM public.memberships m
  WHERE (m.role = 'attending' OR 'attending' = ANY(m.roles))
    AND COALESCE(m.role_approved, true) = false;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'FIX RESULTS:';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Total attendings: %', total_attendings;
  RAISE NOTICE 'Visible in list: %', visible_attendings;
  RAISE NOTICE 'Still missing profiles: %', missing_profile_count;
  RAISE NOTICE 'Still unapproved: %', unapproved_count;
  RAISE NOTICE '========================================';
  
  IF visible_attendings = total_attendings AND missing_profile_count = 0 AND unapproved_count = 0 THEN
    RAISE NOTICE '✅ SUCCESS: All attendings should now appear in the list!';
  ELSIF visible_attendings < total_attendings THEN
    RAISE WARNING '⚠️  Some attendings may still not appear. Check the diagnostic script.';
  END IF;
END $$;

-- STEP 5: Show the final state
SELECT
  m.user_id,
  u.email,
  i.name as institution_name,
  m.role,
  m.roles,
  m.role_approved,
  p.full_name,
  CASE 
    WHEN p.id IS NULL THEN '❌ MISSING PROFILE'
    WHEN COALESCE(m.role_approved, true) = false THEN '❌ NOT APPROVED'
    ELSE '✅ READY'
  END as status
FROM public.memberships m
LEFT JOIN auth.users u ON u.id = m.user_id
LEFT JOIN public.institutions i ON i.id = m.institution_id
LEFT JOIN public.profiles p ON p.id = m.user_id
WHERE m.role = 'attending' OR 'attending' = ANY(m.roles)
ORDER BY m.created_at DESC;

