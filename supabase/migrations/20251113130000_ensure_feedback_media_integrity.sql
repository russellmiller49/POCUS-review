-- 2025-11-13: Ensure data integrity for per-media feedback
-- This migration adds validation to ensure media_id (if provided) belongs to the same study_id

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

