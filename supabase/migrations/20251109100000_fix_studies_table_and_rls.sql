-- Comprehensive fix for studies table and RLS policies
-- This migration ensures the table has all required columns and policies work correctly

-- 1. Add institution_id column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'studies'
        AND column_name = 'institution_id'
    ) THEN
        ALTER TABLE public.studies ADD COLUMN institution_id uuid;

        -- Add foreign key constraint
        ALTER TABLE public.studies
        ADD CONSTRAINT studies_institution_id_fkey
        FOREIGN KEY (institution_id) REFERENCES public.institutions(id);

        -- Add index
        CREATE INDEX IF NOT EXISTS idx_studies_institution_id ON public.studies(institution_id);
    END IF;
END $$;

-- 2. Add exam_type column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'studies'
        AND column_name = 'exam_type'
    ) THEN
        ALTER TABLE public.studies ADD COLUMN exam_type text;
    END IF;
END $$;

-- 3. Add status column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'studies'
        AND column_name = 'status'
    ) THEN
        ALTER TABLE public.studies ADD COLUMN status text NOT NULL DEFAULT 'draft';
    END IF;
END $$;

-- 4. Add submitted_at column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'studies'
        AND column_name = 'submitted_at'
    ) THEN
        ALTER TABLE public.studies ADD COLUMN submitted_at timestamptz;
    END IF;
END $$;

-- 5. Set default for created_by if not already set
ALTER TABLE public.studies
  ALTER COLUMN created_by SET DEFAULT auth.uid();

-- 6. Drop old policies and create new simplified ones
DROP POLICY IF EXISTS "fellow inserts own studies" ON public.studies;
DROP POLICY IF EXISTS "member inserts own studies" ON public.studies;

-- Create a simple INSERT policy that works
-- Users can insert studies they create
CREATE POLICY "authenticated users insert own studies"
ON public.studies
FOR INSERT
TO authenticated
WITH CHECK (
  -- Either created_by matches auth.uid() or it will be set by default
  (created_by = auth.uid() OR created_by IS NULL)
);

-- Keep the select and update policies simple
DROP POLICY IF EXISTS "select studies if authorized" ON public.studies;
CREATE POLICY "select studies if authorized"
ON public.studies
FOR SELECT
TO authenticated
USING (
  created_by = auth.uid()
  OR assigned_attending = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.memberships m
    WHERE m.user_id = auth.uid()
    AND 'admin' = ANY(m.roles)
  )
);

DROP POLICY IF EXISTS "update studies if authorized" ON public.studies;
CREATE POLICY "update studies if authorized"
ON public.studies
FOR UPDATE
TO authenticated
USING (
  created_by = auth.uid()
  OR assigned_attending = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.memberships m
    WHERE m.user_id = auth.uid()
    AND 'admin' = ANY(m.roles)
  )
)
WITH CHECK (
  created_by = auth.uid()
  OR assigned_attending = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.memberships m
    WHERE m.user_id = auth.uid()
    AND 'admin' = ANY(m.roles)
  )
);
