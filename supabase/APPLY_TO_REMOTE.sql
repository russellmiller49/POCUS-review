-- ============================================================================
-- COMPLETE MIGRATION: Per-Media Feedback Support
-- ============================================================================
-- This script applies both migrations needed for per-media feedback:
-- 1. Adds media_id column to feedback table
-- 2. Adds data integrity validation
--
-- INSTRUCTIONS: Copy and paste this ENTIRE file into Supabase Dashboard SQL Editor
-- URL: https://supabase.com/dashboard/project/tqnhxlwvkkswuckszlee/sql/new
-- ============================================================================

-- ============================================================================
-- PART 1: Add media_id column to feedback table
-- ============================================================================

-- 1) Add optional media reference to feedback
ALTER TABLE public.feedback
    ADD COLUMN IF NOT EXISTS media_id uuid
        REFERENCES public.media(id)
        ON DELETE CASCADE;

-- 2) Create index for media_id lookups
CREATE INDEX IF NOT EXISTS idx_feedback_media_id
    ON public.feedback(media_id);

-- 3) Refresh feedback RLS policies to cover the new workflow
DROP POLICY IF EXISTS "attending inserts feedback" ON public.feedback;
DROP POLICY IF EXISTS "attending updates feedback" ON public.feedback;
DROP POLICY IF EXISTS "select feedback if authorized" ON public.feedback;

-- INSERT: attendings/analysts/admins at the same institution (and approved) can add feedback
CREATE POLICY "attending inserts feedback"
ON public.feedback FOR INSERT
TO authenticated
WITH CHECK (
    public.has_admin_role() OR EXISTS (
        SELECT 1
        FROM public.studies s
        JOIN public.memberships m
          ON m.institution_id = s.institution_id
         AND m.user_id = auth.uid()
        WHERE s.id = feedback.study_id
          AND (
              lower(m.role) = ANY(ARRAY['attending','admin','administrator','analyst'])
              OR EXISTS (
                  SELECT 1
                  FROM unnest(COALESCE(m.roles, ARRAY[]::text[])) r(role_text)
                  WHERE lower(r.role_text) = ANY(ARRAY['attending','admin','administrator','analyst'])
              )
          )
          AND COALESCE(m.role_approved, true) = true
    )
);

-- UPDATE: unchanged semantics (reviewer can edit their own feedback, admins override)
CREATE POLICY "attending updates feedback"
ON public.feedback FOR UPDATE
TO authenticated
USING (
    reviewer_id = auth.uid() OR public.has_admin_role()
)
WITH CHECK (
    reviewer_id = auth.uid() OR public.has_admin_role()
);

-- SELECT: any authorized user (existing helper) OR the fellow who created the study
CREATE POLICY "select feedback if authorized"
ON public.feedback FOR SELECT
TO authenticated
USING (
    public.can_access_study(study_id)
    OR EXISTS (
        SELECT 1
        FROM public.studies s
        WHERE s.id = feedback.study_id
          AND s.created_by = auth.uid()
    )
);

-- ============================================================================
-- PART 2: Add data integrity validation
-- ============================================================================

-- 1) Create a function to validate media_id belongs to the same study
-- PostgreSQL doesn't allow subqueries in CHECK constraints, so we use a function
CREATE OR REPLACE FUNCTION public.validate_feedback_media_study_match()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.media_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1
            FROM public.media m
            WHERE m.id = NEW.media_id
              AND m.study_id = NEW.study_id
        ) THEN
            RAISE EXCEPTION 'media_id % does not belong to study_id %', NEW.media_id, NEW.study_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

-- Drop existing constraint and trigger if they exist
ALTER TABLE public.feedback
    DROP CONSTRAINT IF EXISTS feedback_media_study_match;

DROP TRIGGER IF EXISTS trigger_validate_feedback_media_study_match ON public.feedback;

-- Create trigger to enforce the constraint
CREATE TRIGGER trigger_validate_feedback_media_study_match
    BEFORE INSERT OR UPDATE ON public.feedback
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_feedback_media_study_match();

-- 2) Update the INSERT policy to validate media_id belongs to study_id
-- This provides an additional layer of security at the RLS level
DROP POLICY IF EXISTS "attending inserts feedback" ON public.feedback;

CREATE POLICY "attending inserts feedback"
ON public.feedback FOR INSERT
TO authenticated
WITH CHECK (
    public.has_admin_role() OR EXISTS (
        SELECT 1
        FROM public.studies s
        JOIN public.memberships m
          ON m.institution_id = s.institution_id
         AND m.user_id = auth.uid()
        WHERE s.id = feedback.study_id
          AND (
              lower(m.role) = ANY(ARRAY['attending','admin','administrator','analyst'])
              OR EXISTS (
                  SELECT 1
                  FROM unnest(COALESCE(m.roles, ARRAY[]::text[])) r(role_text)
                  WHERE lower(r.role_text) = ANY(ARRAY['attending','admin','administrator','analyst'])
              )
          )
          AND COALESCE(m.role_approved, true) = true
          -- Ensure media_id (if provided) belongs to the same study
          AND (
              feedback.media_id IS NULL
              OR EXISTS (
                  SELECT 1
                  FROM public.media med
                  WHERE med.id = feedback.media_id
                    AND med.study_id = feedback.study_id
              )
          )
    )
);

-- 3) Create a helpful index for querying feedback by media
CREATE INDEX IF NOT EXISTS idx_feedback_study_media
    ON public.feedback(study_id, media_id)
    WHERE media_id IS NOT NULL;

-- 4) Add comment for documentation
COMMENT ON COLUMN public.feedback.media_id IS 
    'Optional reference to a specific media item within the study. If provided, must belong to the same study as study_id.';

-- ============================================================================
-- VERIFICATION: Check that everything was created successfully
-- ============================================================================
SELECT 
    'Migration applied successfully!' as status,
    (SELECT COUNT(*) FROM information_schema.columns 
     WHERE table_schema = 'public' AND table_name = 'feedback' AND column_name = 'media_id') as media_id_column_exists,
    (SELECT COUNT(*) FROM pg_trigger 
     WHERE tgname = 'trigger_validate_feedback_media_study_match') as trigger_exists,
    (SELECT COUNT(*) FROM pg_indexes 
     WHERE indexname = 'idx_feedback_study_media') as index_exists,
    (SELECT COUNT(*) FROM pg_policies 
     WHERE tablename = 'feedback' AND policyname = 'attending inserts feedback') as policy_exists;
