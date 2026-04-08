-- ============================================
-- QUICK CHECK: See ALL attendings and their status
-- ============================================

-- Show all attendings with their status
SELECT
  m.user_id,
  u.email,
  i.name as institution_name,
  m.role,
  m.roles,
  m.role_approved,
  m.created_at,
  CASE 
    WHEN p.id IS NULL THEN '❌ MISSING PROFILE'
    ELSE '✅ Has Profile'
  END as profile_status,
  CASE
    WHEN m.role_approved = false THEN '❌ NOT APPROVED'
    WHEN m.role_approved = true THEN '✅ APPROVED'
    WHEN m.role_approved IS NULL THEN '✅ NULL (approved)'
    ELSE '⚠️ UNKNOWN'
  END as approval_status,
  CASE
    WHEN p.id IS NULL THEN '❌ WON''T APPEAR (no profile)'
    WHEN COALESCE(m.role_approved, true) = false THEN '❌ WON''T APPEAR (not approved)'
    ELSE '✅ WILL APPEAR IN LIST'
  END as will_appear
FROM public.memberships m
LEFT JOIN auth.users u ON u.id = m.user_id
LEFT JOIN public.institutions i ON i.id = m.institution_id
LEFT JOIN public.profiles p ON p.id = m.user_id
WHERE m.role = 'attending' OR 'attending' = ANY(m.roles)
ORDER BY 
  CASE WHEN p.id IS NULL THEN 0 ELSE 1 END,  -- Missing profiles first
  CASE WHEN COALESCE(m.role_approved, true) = false THEN 0 ELSE 1 END,  -- Unapproved first
  m.created_at DESC;

-- Summary counts
SELECT
  COUNT(*) as total_attendings,
  COUNT(p.id) as with_profiles,
  COUNT(*) FILTER (WHERE COALESCE(m.role_approved, true) = true) as approved,
  COUNT(*) FILTER (WHERE p.id IS NOT NULL AND COALESCE(m.role_approved, true) = true) as will_appear_in_list
FROM public.memberships m
LEFT JOIN public.profiles p ON p.id = m.user_id
WHERE m.role = 'attending' OR 'attending' = ANY(m.roles);

