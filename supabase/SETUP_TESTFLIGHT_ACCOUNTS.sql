-- ============================================
-- SETUP TESTFLIGHT REVIEWER ACCOUNTS
-- Run this AFTER creating users in Supabase Dashboard
-- ============================================

-- STEP 1: Create test institution (if it doesn't exist)
INSERT INTO public.institutions (id, slug, name, settings)
VALUES (
  '00000000-0000-0000-0000-000000000001'::uuid,
  'testflight-review',
  'TestFlight Review Institution',
  '{}'::jsonb
)
ON CONFLICT (id) DO NOTHING;

-- STEP 2: Create profiles and memberships for Fellow
-- Replace the user_id with the actual ID from auth.users after creating the user
DO $$
DECLARE
  test_institution_id uuid := '00000000-0000-0000-0000-000000000001'::uuid;
  fellow_user_id uuid;
  attending_user_id uuid;
  admin_user_id uuid;
BEGIN
  -- Get user IDs by email
  SELECT id INTO fellow_user_id FROM auth.users WHERE email = 'reviewer.fellow@testflight.app';
  SELECT id INTO attending_user_id FROM auth.users WHERE email = 'reviewer.attending@testflight.app';
  SELECT id INTO admin_user_id FROM auth.users WHERE email = 'reviewer.admin@testflight.app';
  
  -- Fellow account
  IF fellow_user_id IS NOT NULL THEN
    INSERT INTO public.profiles (id, email, full_name)
    VALUES (fellow_user_id, 'reviewer.fellow@testflight.app', 'TestFlight Fellow')
    ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email,
        full_name = COALESCE(profiles.full_name, EXCLUDED.full_name);
    
    INSERT INTO public.memberships (user_id, institution_id, role, roles, role_approved)
    VALUES (fellow_user_id, test_institution_id, 'fellow', ARRAY['fellow']::text[], true)
    ON CONFLICT (user_id, institution_id) DO UPDATE
    SET role = 'fellow',
        roles = ARRAY['fellow']::text[],
        role_approved = true,
        updated_at = now();
    
    RAISE NOTICE '✅ Fellow account configured';
  ELSE
    RAISE WARNING '⚠️  Fellow user not found. Create user in Supabase Dashboard first.';
  END IF;
  
  -- Attending account
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
    
    RAISE NOTICE '✅ Attending account configured';
  ELSE
    RAISE WARNING '⚠️  Attending user not found. Create user in Supabase Dashboard first.';
  END IF;
  
  -- Admin account
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
    
    RAISE NOTICE '✅ Admin account configured';
  ELSE
    RAISE WARNING '⚠️  Admin user not found. Create user in Supabase Dashboard first.';
  END IF;
END $$;

-- STEP 3: Verify setup
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

