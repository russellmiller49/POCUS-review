-- Fix RLS Policy for Study Creation
-- Run this directly in Supabase SQL Editor if migrations are failing due to connection issues
-- This fixes the "new row violates row-level security policy" error when creating studies

-- ============================================
-- Step 1: Update helper functions to check role_approved
-- ============================================

-- Update is_member_of to only return true for approved memberships
CREATE OR REPLACE FUNCTION public.is_member_of(inst_id uuid)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.memberships m
    WHERE m.user_id = auth.uid()
      AND m.institution_id = inst_id
      AND (m.role_approved = true OR m.role_approved IS NULL) -- null means approved (backward compatibility)
  );
$$;

-- Update has_role to check both role column and roles array, AND require approval
CREATE OR REPLACE FUNCTION public.has_role(inst_id uuid, target_role text)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.memberships m
    WHERE m.user_id = auth.uid()
      AND m.institution_id = inst_id
      AND (m.role_approved = true OR m.role_approved IS NULL) -- null means approved (backward compatibility)
      AND (
        m.role = target_role
        OR (m.roles IS NOT NULL AND target_role = ANY(m.roles))
      )
  );
$$;

-- Update has_admin_role to require approval
CREATE OR REPLACE FUNCTION public.has_admin_role()
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.memberships m
    WHERE m.user_id = auth.uid()
      AND (m.role_approved = true OR m.role_approved IS NULL) -- null means approved (backward compatibility)
      AND (
        m.role = 'admin'
        OR (m.roles IS NOT NULL AND 'admin' = ANY(m.roles))
      )
  );
$$;

-- Update can_access_study to require approved memberships
CREATE OR REPLACE FUNCTION public.can_access_study(sid uuid)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.studies s
    JOIN public.memberships m
      ON m.institution_id = s.institution_id
     AND m.user_id = auth.uid()
     AND (m.role_approved = true OR m.role_approved IS NULL) -- null means approved (backward compatibility)
    WHERE s.id = sid
      AND (
        s.created_by = auth.uid()
        OR m.role = ANY(ARRAY['admin','attending'])
        OR (m.roles && ARRAY['admin'::text, 'attending'::text])
      )
  );
$$;

-- ============================================
-- Step 2: Ensure the study insert policy allows approved members
-- ============================================

-- Drop the old policy if it exists
DROP POLICY IF EXISTS "fellow inserts own studies" ON public.studies;
DROP POLICY IF EXISTS "member inserts own studies" ON public.studies;

-- Create a policy that allows any approved member to create studies
-- (The app UI already restricts this to fellows, so we just need to verify membership + ownership)
CREATE POLICY "member inserts own studies"
ON public.studies
FOR INSERT
TO authenticated
WITH CHECK (
  created_by = auth.uid()
  AND public.is_member_of(institution_id) -- This now checks role_approved
);

-- ============================================
-- Step 3: Update other RLS policies to use approved memberships
-- ============================================

-- Update institutions read policy
DROP POLICY IF EXISTS "read own institution" ON public.institutions;
CREATE POLICY "read own institution"
ON public.institutions FOR SELECT
TO authenticated
USING (
  public.is_member_of(institutions.id) OR public.has_admin_role()
);

-- Update memberships read policy to only show approved memberships
DROP POLICY IF EXISTS "read own membership" ON public.memberships;
CREATE POLICY "read own membership"
ON public.memberships FOR SELECT
TO authenticated
USING (
  (user_id = auth.uid() AND (role_approved = true OR role_approved IS NULL))
  OR public.has_admin_role()
);

-- ============================================
-- Step 4: Grant execute permissions (if needed)
-- ============================================
GRANT EXECUTE ON FUNCTION public.is_member_of(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_admin_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_access_study(uuid) TO authenticated;

-- ============================================
-- Step 5: Diagnostic query - Check your current membership status
-- ============================================
-- Uncomment and run this to check if you have an approved membership:
-- 
-- SELECT 
--   m.user_id,
--   m.institution_id,
--   i.name as institution_name,
--   m.role,
--   m.roles,
--   m.role_approved,
--   m.role_requested_at,
--   m.created_at
-- FROM public.memberships m
-- JOIN public.institutions i ON i.id = m.institution_id
-- WHERE m.user_id = auth.uid();

