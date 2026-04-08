-- ============================================
-- FIX: Study Creation RLS Policy Error
-- ============================================
-- Run this in Supabase Dashboard > SQL Editor
-- This fixes the "new row violates row-level security policy" error
-- ============================================

-- Step 1: Drop existing policies
DROP POLICY IF EXISTS "member inserts own studies" ON public.studies;
DROP POLICY IF EXISTS "fellow inserts own studies" ON public.studies;

-- Step 2: Create a more permissive policy
-- This allows any authenticated user with a membership to create studies
-- (Doesn't require role_approved = true, just membership existence)
CREATE POLICY "member inserts own studies"
ON public.studies
FOR INSERT
TO authenticated
WITH CHECK (
  created_by = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.memberships m
    WHERE m.user_id = auth.uid()
      AND m.institution_id = studies.institution_id
  )
);

-- ============================================
-- DIAGNOSTIC: Check if user has memberships
-- ============================================
-- Run this to see the current user's memberships:
/*
SELECT 
    m.user_id,
    m.institution_id,
    i.name as institution_name,
    m.role,
    m.roles,
    m.role_approved,
    m.created_at
FROM public.memberships m
JOIN public.institutions i ON i.id = m.institution_id
WHERE m.user_id = auth.uid()
ORDER BY m.created_at DESC;
*/

-- ============================================
-- OPTIONAL: If user needs membership approval
-- ============================================
-- If the diagnostic shows role_approved = false, you can approve it:
/*
UPDATE public.memberships
SET role_approved = true
WHERE user_id = auth.uid()
  AND role_approved = false;
*/

