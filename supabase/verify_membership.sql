-- Quick Verification Query
-- Run this to check if your membership exists and is set up correctly

SELECT 
    m.user_id,
    m.institution_id,
    i.name as institution_name,
    i.slug as institution_slug,
    m.role,
    m.roles,
    m.role_approved,
    m.pgy_year,
    m.created_at,
    m.updated_at,
    CASE 
        WHEN m.role_approved = true THEN '✅ APPROVED - Should be able to create studies'
        WHEN m.role_approved = false THEN '❌ PENDING - Needs approval'
        ELSE '⚠️ NULL - May need to set to true'
    END as status
FROM public.memberships m
JOIN public.institutions i ON i.id = m.institution_id
WHERE m.user_id = 'db9d49e5-10bb-49d1-ae0d-63893b84e308'::uuid;

-- Expected result: You should see 1 row with:
-- - role: 'fellow'
-- - role_approved: true
-- - status: '✅ APPROVED - Should be able to create studies'














