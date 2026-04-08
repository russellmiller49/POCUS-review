-- Simplest possible fix: allow any authenticated user to insert studies they own
-- Remove all complex role-based checks

DROP POLICY IF EXISTS "fellow inserts own studies" ON public.studies;
DROP POLICY IF EXISTS "member inserts own studies" ON public.studies;
DROP POLICY IF EXISTS "authenticated users insert own studies" ON public.studies;

CREATE POLICY "anyone_can_insert_own_study"
ON public.studies
FOR INSERT
TO authenticated
WITH CHECK (created_by = auth.uid());
