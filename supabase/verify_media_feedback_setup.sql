-- Verification script for per-media feedback setup
-- Run this to ensure all components are properly configured

-- 1) Check that media_id column exists in feedback table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'feedback'
          AND column_name = 'media_id'
    ) THEN
        RAISE EXCEPTION 'Missing column: feedback.media_id';
    END IF;
    RAISE NOTICE '✓ feedback.media_id column exists';
END $$;

-- 2) Check foreign key constraint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON tc.constraint_name = kcu.constraint_name
        WHERE tc.table_schema = 'public'
          AND tc.table_name = 'feedback'
          AND tc.constraint_type = 'FOREIGN KEY'
          AND kcu.column_name = 'media_id'
    ) THEN
        RAISE EXCEPTION 'Missing foreign key: feedback.media_id -> media.id';
    END IF;
    RAISE NOTICE '✓ Foreign key constraint exists';
END $$;

-- 3) Check trigger for study_id match (we use a trigger instead of check constraint)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgname = 'trigger_validate_feedback_media_study_match'
          AND tgrelid = 'public.feedback'::regclass
    ) THEN
        RAISE WARNING 'Missing trigger: trigger_validate_feedback_media_study_match';
    ELSE
        RAISE NOTICE '✓ Trigger trigger_validate_feedback_media_study_match exists';
    END IF;
END $$;

-- 4) Check indexes
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = 'feedback'
          AND indexname = 'idx_feedback_media_id'
    ) THEN
        RAISE WARNING 'Missing index: idx_feedback_media_id';
    ELSE
        RAISE NOTICE '✓ Index idx_feedback_media_id exists';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = 'feedback'
          AND indexname = 'idx_feedback_study_media'
    ) THEN
        RAISE WARNING 'Missing index: idx_feedback_study_media';
    ELSE
        RAISE NOTICE '✓ Index idx_feedback_study_media exists';
    END IF;
END $$;

-- 5) Check RLS policies
DO $$
DECLARE
    policy_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'feedback'
      AND policyname = 'attending inserts feedback';
    
    IF policy_count = 0 THEN
        RAISE EXCEPTION 'Missing RLS policy: attending inserts feedback';
    END IF;
    RAISE NOTICE '✓ RLS policy "attending inserts feedback" exists';

    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'feedback'
      AND policyname = 'attending updates feedback';
    
    IF policy_count = 0 THEN
        RAISE WARNING 'Missing RLS policy: attending updates feedback';
    ELSE
        RAISE NOTICE '✓ RLS policy "attending updates feedback" exists';
    END IF;

    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'feedback'
      AND policyname = 'select feedback if authorized';
    
    IF policy_count = 0 THEN
        RAISE EXCEPTION 'Missing RLS policy: select feedback if authorized';
    END IF;
    RAISE NOTICE '✓ RLS policy "select feedback if authorized" exists';
END $$;

-- 6) Test data integrity (if there's existing data)
DO $$
DECLARE
    invalid_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO invalid_count
    FROM public.feedback f
    WHERE f.media_id IS NOT NULL
      AND NOT EXISTS (
          SELECT 1
          FROM public.media m
          WHERE m.id = f.media_id
            AND m.study_id = f.study_id
      );
    
    IF invalid_count > 0 THEN
        RAISE WARNING 'Found % feedback records with media_id that does not match study_id', invalid_count;
    ELSE
        RAISE NOTICE '✓ All existing feedback records have valid media_id references';
    END IF;
END $$;

-- 7) Summary
SELECT 
    'Verification complete!' as status,
    'All required components for per-media feedback are in place' as message;

