-- ============================================
-- Add User Role/Membership for russellmiller49@gmail.com
-- ============================================
-- Run this in Supabase Dashboard → SQL Editor
-- Make sure you're logged in as a user with admin privileges

-- Step 1: Create a default institution if it doesn't exist
INSERT INTO public.institutions (slug, name, settings)
VALUES ('default-institution', 'Default Institution', '{}'::jsonb)
ON CONFLICT (slug) DO NOTHING
RETURNING id, slug, name;

-- Step 2: Get the institution ID (use the ID from Step 1, or run this to find it)
-- Replace 'default-institution' with your institution slug if different
SELECT id, slug, name 
FROM public.institutions 
WHERE slug = 'default-institution';

-- Step 3: Add membership with ADMIN role (change 'admin' to 'fellow' or 'attending' if needed)
-- Replace 'INSTITUTION_ID_FROM_STEP_2' with the actual UUID from Step 2
INSERT INTO public.memberships (user_id, institution_id, role)
SELECT 
    'c0afbb5e-bf22-46d1-b77a-bf4df38a1d81'::uuid,  -- Your user ID
    i.id,                                           -- Institution ID
    'admin'                                         -- Role: 'fellow', 'attending', or 'admin'
FROM public.institutions i
WHERE i.slug = 'default-institution'
ON CONFLICT (user_id, institution_id) 
DO UPDATE SET role = EXCLUDED.role
RETURNING *;

-- Step 4: Verify the membership was created
SELECT 
    m.user_id,
    m.institution_id,
    m.role,
    m.roles,
    i.name as institution_name,
    i.slug as institution_slug,
    u.email
FROM public.memberships m
JOIN public.institutions i ON i.id = m.institution_id
JOIN auth.users u ON u.id = m.user_id
WHERE m.user_id = 'c0afbb5e-bf22-46d1-b77a-bf4df38a1d81'::uuid;

-- ============================================
-- ALTERNATIVE: If you already have an institution
-- ============================================
-- If you know your institution ID, use this instead:

-- INSERT INTO public.memberships (user_id, institution_id, role)
-- VALUES (
--     'c0afbb5e-bf22-46d1-b77a-bf4df38a1d81'::uuid,
--     'YOUR_INSTITUTION_ID_HERE'::uuid,  -- Replace with actual UUID
--     'admin'                             -- 'fellow', 'attending', or 'admin'
-- )
-- ON CONFLICT (user_id, institution_id) 
-- DO UPDATE SET role = EXCLUDED.role
-- RETURNING *;
