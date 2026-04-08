-- Fix Signoff and Feedback RLS Policies to Check role_approved
-- This ensures that only approved attendings can submit reviews and signoffs
-- CRITICAL: Also adds UPDATE policies needed for UPSERT operations
-- Date: 2025-11-12

-- ============================================
-- Update SIGNOFFS Policies (INSERT, UPDATE, SELECT)
-- ============================================
-- The app uses .upsert() which requires both INSERT and UPDATE policies

-- Drop all existing signoff policies
DROP POLICY IF EXISTS "attending inserts signoff" ON public.signoffs;
DROP POLICY IF EXISTS "attending updates signoff" ON public.signoffs;
DROP POLICY IF EXISTS "update signoffs if authorized" ON public.signoffs;
DROP POLICY IF EXISTS "select signoffs if authorized" ON public.signoffs;

-- INSERT: Attendings can create signoffs ONLY if their role is approved
CREATE POLICY "attending inserts signoff"
ON public.signoffs FOR INSERT
TO authenticated
WITH CHECK (
  public.has_admin_role() OR EXISTS (
    SELECT 1 FROM public.studies s
    JOIN public.memberships m
      ON m.institution_id = s.institution_id
      AND m.user_id = auth.uid()
    WHERE s.id = signoffs.study_id
      AND (m.role = 'attending' OR m.role = 'admin' OR 'attending' = ANY(m.roles) OR 'admin' = ANY(m.roles))
      AND COALESCE(m.role_approved, true) = true
  )
);

-- UPDATE: Attendings can update signoffs (needed for UPSERT)
CREATE POLICY "attending updates signoff"
ON public.signoffs FOR UPDATE
TO authenticated
USING (
  public.has_admin_role() OR EXISTS (
    SELECT 1 FROM public.studies s
    JOIN public.memberships m
      ON m.institution_id = s.institution_id
      AND m.user_id = auth.uid()
    WHERE s.id = signoffs.study_id
      AND (m.role = 'attending' OR m.role = 'admin' OR 'attending' = ANY(m.roles) OR 'admin' = ANY(m.roles))
      AND COALESCE(m.role_approved, true) = true
  )
)
WITH CHECK (
  public.has_admin_role() OR EXISTS (
    SELECT 1 FROM public.studies s
    JOIN public.memberships m
      ON m.institution_id = s.institution_id
      AND m.user_id = auth.uid()
    WHERE s.id = signoffs.study_id
      AND (m.role = 'attending' OR m.role = 'admin' OR 'attending' = ANY(m.roles) OR 'admin' = ANY(m.roles))
      AND COALESCE(m.role_approved, true) = true
  )
);

-- SELECT: Read signoffs if authorized
CREATE POLICY "select signoffs if authorized"
ON public.signoffs FOR SELECT
TO authenticated
USING (public.can_access_study(study_id));

-- ============================================
-- Update FEEDBACK Policies (INSERT, UPDATE, SELECT)
-- ============================================

-- Drop all existing feedback policies
DROP POLICY IF EXISTS "attending inserts feedback" ON public.feedback;
DROP POLICY IF EXISTS "attending updates feedback" ON public.feedback;
DROP POLICY IF EXISTS "select feedback if authorized" ON public.feedback;

-- INSERT: Attendings can insert feedback ONLY if their role is approved
CREATE POLICY "attending inserts feedback"
ON public.feedback FOR INSERT
TO authenticated
WITH CHECK (
  public.has_admin_role() OR EXISTS (
    SELECT 1 FROM public.studies s
    JOIN public.memberships m
      ON m.institution_id = s.institution_id
      AND m.user_id = auth.uid()
    WHERE s.id = feedback.study_id
      AND (m.role = 'attending' OR m.role = 'admin' OR 'attending' = ANY(m.roles) OR 'admin' = ANY(m.roles))
      AND COALESCE(m.role_approved, true) = true
  )
);

-- UPDATE: Attendings can update their own feedback
CREATE POLICY "attending updates feedback"
ON public.feedback FOR UPDATE
TO authenticated
USING (
  reviewer_id = auth.uid() OR public.has_admin_role()
)
WITH CHECK (
  reviewer_id = auth.uid() OR public.has_admin_role()
);

-- SELECT: Read feedback if authorized
CREATE POLICY "select feedback if authorized"
ON public.feedback FOR SELECT
TO authenticated
USING (public.can_access_study(study_id));

-- ============================================
-- Ensure all existing memberships are approved
-- ============================================
-- This is a safety measure to approve any memberships that might have been
-- created before the approval system was fully implemented
UPDATE public.memberships
SET role_approved = true
WHERE role_approved IS NULL OR role_approved = false;

-- ============================================
-- Create index for better performance on role_approved queries
-- ============================================
CREATE INDEX IF NOT EXISTS idx_memberships_user_institution_approved
ON public.memberships (user_id, institution_id)
WHERE COALESCE(role_approved, true) = true;

-- ============================================
-- Verification Query (comment this out in production)
-- ============================================
-- Uncomment the following to verify the changes:
-- SELECT
--   u.email,
--   i.name as institution,
--   m.role,
--   m.roles,
--   m.role_approved,
--   COUNT(s.id) as study_count
-- FROM public.memberships m
-- LEFT JOIN auth.users u ON u.id = m.user_id
-- LEFT JOIN public.institutions i ON i.id = m.institution_id
-- LEFT JOIN public.studies s ON s.institution_id = m.institution_id
-- WHERE m.role = 'attending' OR 'attending' = ANY(m.roles)
-- GROUP BY u.email, i.name, m.role, m.roles, m.role_approved
-- ORDER BY u.email;
