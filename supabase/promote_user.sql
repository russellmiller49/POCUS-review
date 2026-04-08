-- Manual User Promotion Script
-- Use this to promote users from 'fellow' to 'attending' or 'admin'

-- ============================================
-- Promote User by Email
-- ============================================
-- Replace values below and run

-- Example: Promote user to admin
UPDATE public.memberships
SET role = 'admin'  -- Change to 'attending' or 'admin'
WHERE user_id = (
    SELECT id FROM auth.users WHERE email = 'user@example.com'
)
AND institution_id = (
    SELECT id FROM public.institutions WHERE slug = 'default-institution'
    -- Or use specific institution_id if you know it
);

-- ============================================
-- Promote User by User ID
-- ============================================
-- If you know the user ID directly:
UPDATE public.memberships
SET role = 'admin'  -- or 'attending'
WHERE user_id = 'USER_ID_HERE'::uuid
AND institution_id = 'INSTITUTION_ID_HERE'::uuid;

-- ============================================
-- Promote User in All Institutions
-- ============================================
-- Promote a user to admin across all their institutions:
UPDATE public.memberships
SET role = 'admin'
WHERE user_id = (
    SELECT id FROM auth.users WHERE email = 'user@example.com'
);

-- ============================================
-- Promote Multiple Users at Once
-- ============================================
-- Promote multiple users to attending:
UPDATE public.memberships
SET role = 'attending'
WHERE user_id IN (
    SELECT id FROM auth.users 
    WHERE email IN (
        'user1@example.com',
        'user2@example.com',
        'user3@example.com'
    )
)
AND institution_id = (
    SELECT id FROM public.institutions WHERE slug = 'default-institution'
);

-- ============================================
-- Add Additional Role (Keep Existing + Add New)
-- ============================================
-- If you want a user to have multiple roles in the same institution,
-- you can add to the roles array (if your schema supports it):
UPDATE public.memberships
SET roles = array_append(COALESCE(roles, ARRAY[role]), 'admin')
WHERE user_id = 'USER_ID_HERE'::uuid
AND institution_id = 'INSTITUTION_ID_HERE'::uuid;

-- ============================================
-- Verify Promotion
-- ============================================
-- Check user's current role after promotion:
SELECT 
    u.email,
    i.name as institution_name,
    m.role,
    m.roles,
    m.created_at as role_assigned_at,
    m.updated_at as role_updated_at
FROM public.memberships m
JOIN auth.users u ON u.id = m.user_id
JOIN public.institutions i ON i.id = m.institution_id
WHERE u.email = 'user@example.com';
















