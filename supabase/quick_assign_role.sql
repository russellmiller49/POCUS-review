-- Quick Script: Assign Role to New User
-- Replace the values below and run in Supabase SQL Editor

-- ============================================
-- STEP 1: Find User ID by Email
-- ============================================
SELECT id, email, created_at 
FROM auth.users 
WHERE email = 'user@example.com';  -- Replace with actual email

-- ============================================
-- STEP 2: Find Institution ID
-- ============================================
SELECT id, slug, name 
FROM public.institutions;

-- ============================================
-- STEP 3: Assign Role (Replace UUIDs below)
-- ============================================
INSERT INTO public.memberships (user_id, institution_id, role)
VALUES (
    'USER_ID_HERE'::uuid,           -- From Step 1
    'INSTITUTION_ID_HERE'::uuid,    -- From Step 2
    'fellow'                        -- 'fellow', 'attending', or 'admin'
)
ON CONFLICT (user_id, institution_id) 
DO UPDATE SET role = EXCLUDED.role
RETURNING *;

-- ============================================
-- STEP 4: Verify Assignment
-- ============================================
SELECT 
    u.email,
    i.name as institution_name,
    m.role,
    m.created_at as assigned_at
FROM public.memberships m
JOIN auth.users u ON u.id = m.user_id
JOIN public.institutions i ON i.id = m.institution_id
WHERE m.user_id = 'USER_ID_HERE'::uuid;



