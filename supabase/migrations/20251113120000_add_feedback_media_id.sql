-- 2025-11-13: Allow per-media feedback by attaching optional media references
-- and ensure fellows/attendings/analysts have the correct policy coverage.

-- 1) Add optional media reference to feedback
ALTER TABLE public.feedback
    ADD COLUMN IF NOT EXISTS media_id uuid
        REFERENCES public.media(id)
        ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_feedback_media_id
    ON public.feedback(media_id);

-- 2) Refresh feedback RLS policies to cover the new workflow
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
