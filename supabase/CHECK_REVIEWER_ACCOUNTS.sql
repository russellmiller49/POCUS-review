-- ============================================
-- CHECK TESTFLIGHT REVIEWER ACCOUNTS
-- Run this to see if accounts exist and their status
-- ============================================

-- Check if users exist in auth.users
SELECT
  'User Check' as check_type,
  email,
  CASE 
    WHEN email_confirmed_at IS NOT NULL THEN '✅ Confirmed'
    WHEN email_confirmed_at IS NULL AND created_at > now() - interval '1 hour' THEN '⚠️  Not Confirmed (may need Auto Confirm)'
    ELSE '❌ Not Confirmed'
  END as confirmation_status,
  created_at
FROM auth.users
WHERE email IN (
  'reviewer.fellow@testflight.app',
  'reviewer.attending@testflight.app',
  'reviewer.admin@testflight.app'
)
ORDER BY email;

-- Check if profiles exist
SELECT
  'Profile Check' as check_type,
  p.email,
  p.full_name,
  CASE 
    WHEN p.id IS NOT NULL THEN '✅ Exists'
    ELSE '❌ Missing'
  END as status
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
WHERE u.email IN (
  'reviewer.fellow@testflight.app',
  'reviewer.attending@testflight.app',
  'reviewer.admin@testflight.app'
)
ORDER BY u.email;

-- Check if memberships exist
SELECT
  'Membership Check' as check_type,
  u.email,
  i.name as institution,
  m.role,
  m.roles,
  m.role_approved,
  CASE
    WHEN m.user_id IS NULL THEN '❌ Missing Membership'
    WHEN COALESCE(m.role_approved, true) = false THEN '⚠️  Not Approved'
    ELSE '✅ Ready'
  END as status
FROM auth.users u
LEFT JOIN public.memberships m ON m.user_id = u.id
LEFT JOIN public.institutions i ON i.id = m.institution_id
WHERE u.email IN (
  'reviewer.fellow@testflight.app',
  'reviewer.attending@testflight.app',
  'reviewer.admin@testflight.app'
)
ORDER BY u.email;

-- Summary
SELECT
  COUNT(*) FILTER (WHERE u.email IS NOT NULL) as users_exist,
  COUNT(*) FILTER (WHERE p.id IS NOT NULL) as profiles_exist,
  COUNT(*) FILTER (WHERE m.user_id IS NOT NULL AND COALESCE(m.role_approved, true) = true) as ready_accounts,
  CASE
    WHEN COUNT(*) FILTER (WHERE u.email IS NOT NULL) = 0 THEN '❌ No users found - Create them in Dashboard first'
    WHEN COUNT(*) FILTER (WHERE u.email IS NOT NULL) < 3 THEN '⚠️  Some users missing'
    WHEN COUNT(*) FILTER (WHERE p.id IS NOT NULL) < 3 THEN '⚠️  Some profiles missing - Run SETUP_TESTFLIGHT_ACCOUNTS.sql'
    WHEN COUNT(*) FILTER (WHERE m.user_id IS NOT NULL AND COALESCE(m.role_approved, true) = true) < 3 THEN '⚠️  Some memberships missing/not approved - Run SETUP_TESTFLIGHT_ACCOUNTS.sql'
    ELSE '✅ All accounts ready!'
  END as overall_status
FROM (
  SELECT 'reviewer.fellow@testflight.app' as email
  UNION ALL SELECT 'reviewer.attending@testflight.app'
  UNION ALL SELECT 'reviewer.admin@testflight.app'
) expected
LEFT JOIN auth.users u ON u.email = expected.email
LEFT JOIN public.profiles p ON p.id = u.id
LEFT JOIN public.memberships m ON m.user_id = u.id AND COALESCE(m.role_approved, true) = true;

