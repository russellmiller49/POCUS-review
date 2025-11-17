-- ============================================
-- CREATE TESTFLIGHT REVIEWER ACCOUNTS
-- These accounts allow App Store reviewers to test the app
-- without needing email verification
-- ============================================

-- STEP 1: Create test accounts in auth.users
-- Note: These will need to be created via Supabase Dashboard or API
-- This script shows what accounts to create and their credentials

-- Test Account 1: Fellow
-- Email: reviewer.fellow@testflight.app
-- Password: TestFlight2024!
-- Role: Fellow

-- Test Account 2: Attending
-- Email: reviewer.attending@testflight.app
-- Password: TestFlight2024!
-- Role: Attending

-- Test Account 3: Admin
-- Email: reviewer.admin@testflight.app
-- Password: TestFlight2024!
-- Role: Admin

-- STEP 2: After creating users in Supabase Dashboard, run this to set up memberships
-- First, get or create a test institution
DO $$
DECLARE
  test_institution_id uuid;
BEGIN
  -- Try to find existing test institution
  SELECT id INTO test_institution_id
  FROM public.institutions
  WHERE slug = 'testflight-review' OR name = 'TestFlight Review Institution'
  LIMIT 1;
  
  -- Create if doesn't exist
  IF test_institution_id IS NULL THEN
    INSERT INTO public.institutions (id, slug, name, settings)
    VALUES (
      gen_random_uuid(),
      'testflight-review',
      'TestFlight Review Institution',
      '{}'::jsonb
    )
    RETURNING id INTO test_institution_id;
  END IF;
  
  RAISE NOTICE 'Test institution ID: %', test_institution_id;
END $$;

-- STEP 3: Create profiles and memberships for test accounts
-- (Run this AFTER creating users in Supabase Dashboard)

-- Get the test institution ID
DO $$
DECLARE
  test_institution_id uuid;
  fellow_user_id uuid;
  attending_user_id uuid;
  admin_user_id uuid;
BEGIN
  -- Get test institution
  SELECT id INTO test_institution_id
  FROM public.institutions
  WHERE slug = 'testflight-review'
  LIMIT 1;
  
  -- Get user IDs (you'll need to replace these with actual user IDs from auth.users)
  -- Or use email lookup:
  SELECT id INTO fellow_user_id FROM auth.users WHERE email = 'reviewer.fellow@testflight.app';
  SELECT id INTO attending_user_id FROM auth.users WHERE email = 'reviewer.attending@testflight.app';
  SELECT id INTO admin_user_id FROM auth.users WHERE email = 'reviewer.admin@testflight.app';
  
  -- Create profiles
  IF fellow_user_id IS NOT NULL THEN
    INSERT INTO public.profiles (id, email, full_name)
    VALUES (fellow_user_id, 'reviewer.fellow@testflight.app', 'TestFlight Fellow')
    ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email,
        full_name = COALESCE(profiles.full_name, EXCLUDED.full_name);
    
    -- Create membership
    INSERT INTO public.memberships (user_id, institution_id, role, roles, role_approved)
    VALUES (fellow_user_id, test_institution_id, 'fellow', ARRAY['fellow']::text[], true)
    ON CONFLICT (user_id, institution_id) DO UPDATE
    SET role = 'fellow',
        roles = ARRAY['fellow']::text[],
        role_approved = true,
        updated_at = now();
  END IF;
  
  IF attending_user_id IS NOT NULL THEN
    INSERT INTO public.profiles (id, email, full_name)
    VALUES (attending_user_id, 'reviewer.attending@testflight.app', 'TestFlight Attending')
    ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email,
        full_name = COALESCE(profiles.full_name, EXCLUDED.full_name);
    
    INSERT INTO public.memberships (user_id, institution_id, role, roles, role_approved)
    VALUES (attending_user_id, test_institution_id, 'attending', ARRAY['attending']::text[], true)
    ON CONFLICT (user_id, institution_id) DO UPDATE
    SET role = 'attending',
        roles = ARRAY['attending']::text[],
        role_approved = true,
        updated_at = now();
  END IF;
  
  IF admin_user_id IS NOT NULL THEN
    INSERT INTO public.profiles (id, email, full_name)
    VALUES (admin_user_id, 'reviewer.admin@testflight.app', 'TestFlight Admin')
    ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email,
        full_name = COALESCE(profiles.full_name, EXCLUDED.full_name);
    
    INSERT INTO public.memberships (user_id, institution_id, role, roles, role_approved)
    VALUES (admin_user_id, test_institution_id, 'admin', ARRAY['admin']::text[], true)
    ON CONFLICT (user_id, institution_id) DO UPDATE
    SET role = 'admin',
        roles = ARRAY['admin']::text[],
        role_approved = true,
        updated_at = now();
  END IF;
  
  RAISE NOTICE 'Test accounts configured';
END $$;

-- STEP 4: Verify the setup
SELECT
  u.email,
  p.full_name,
  i.name as institution,
  m.role,
  m.roles,
  m.role_approved,
  CASE
    WHEN p.id IS NULL THEN '❌ Missing Profile'
    WHEN COALESCE(m.role_approved, true) = false THEN '❌ Not Approved'
    ELSE '✅ Ready'
  END as status
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
LEFT JOIN public.memberships m ON m.user_id = u.id
LEFT JOIN public.institutions i ON i.id = m.institution_id
WHERE u.email LIKE 'reviewer.%@testflight.app'
ORDER BY u.email;

