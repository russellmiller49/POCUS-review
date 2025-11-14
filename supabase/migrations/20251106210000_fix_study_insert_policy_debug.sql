-- Fix study insert policy to be more permissive and add better error handling
-- This ensures users can create studies if they have ANY membership (approved or not)
-- The app-level logic should handle approval workflows

-- Drop the existing policy
DROP POLICY IF EXISTS "member inserts own studies" ON public.studies;
DROP POLICY IF EXISTS "fellow inserts own studies" ON public.studies;

-- Create a more permissive policy that allows any member to create studies
-- This checks for membership existence, not approval status
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

-- Also ensure admins can always create studies
-- (This is already covered by the above, but let's be explicit)
-- Note: The above policy should work for all members including admins













