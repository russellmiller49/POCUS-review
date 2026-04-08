-- Create Membership for Current User
-- Run this in Supabase SQL Editor to create an approved membership for yourself

-- Step 1: Check available institutions
SELECT id, slug, name FROM public.institutions ORDER BY name;

-- Step 2: Create membership for current user
-- Replace 'naval-medical-center-san-diego' with your desired institution slug
-- Options: 'naval-medical-center-san-diego' or 'university-of-california-san-diego'
INSERT INTO public.memberships (
    user_id, 
    institution_id, 
    role, 
    role_approved,
    pgy_year  -- Optional: only for fellows (PGY-4, PGY-5, or PGY-6)
)
SELECT 
    auth.uid(),                    -- Your user ID
    i.id,                          -- Institution ID
    'fellow',                      -- Role: 'fellow', 'attending', or 'admin'
    true,                          -- Approved immediately
    'PGY-4'                        -- PGY year (only for fellows, can be NULL for attending/admin)
FROM public.institutions i
WHERE i.slug = 'naval-medical-center-san-diego'  -- Change this to your institution
ON CONFLICT (user_id, institution_id) 
DO UPDATE SET 
    role = EXCLUDED.role,
    role_approved = true,
    pgy_year = COALESCE(EXCLUDED.pgy_year, memberships.pgy_year);

-- Step 3: Verify the membership was created
SELECT 
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
WHERE m.user_id = auth.uid();














