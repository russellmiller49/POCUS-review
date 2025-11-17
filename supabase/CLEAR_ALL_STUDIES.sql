-- ============================================
-- CLEAR ALL STUDIES AND RELATED DATA
-- This script deletes all studies, which will CASCADE delete:
--   - All media (images/videos)
--   - All feedback (attending reviews)
--   - All signoffs (approval status)
--
-- PRESERVES:
--   - Users (auth.users)
--   - Institutions
--   - Memberships
--   - Profiles
-- ============================================

-- STEP 1: Show what will be deleted (for verification)
DO $$
DECLARE
  study_count integer;
  media_count integer;
  feedback_count integer;
  signoff_count integer;
BEGIN
  SELECT COUNT(*) INTO study_count FROM public.studies;
  SELECT COUNT(*) INTO media_count FROM public.media;
  SELECT COUNT(*) INTO feedback_count FROM public.feedback;
  SELECT COUNT(*) INTO signoff_count FROM public.signoffs;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'CURRENT DATA COUNTS:';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Studies: %', study_count;
  RAISE NOTICE 'Media: %', media_count;
  RAISE NOTICE 'Feedback: %', feedback_count;
  RAISE NOTICE 'Signoffs: %', signoff_count;
  RAISE NOTICE '========================================';
END $$;

-- STEP 2: Delete all studies (CASCADE will handle related data)
-- This will automatically delete:
--   - All media (ON DELETE CASCADE)
--   - All feedback (ON DELETE CASCADE)
--   - All signoffs (ON DELETE CASCADE)
DELETE FROM public.studies;

-- STEP 3: Verify deletion
DO $$
DECLARE
  study_count integer;
  media_count integer;
  feedback_count integer;
  signoff_count integer;
BEGIN
  SELECT COUNT(*) INTO study_count FROM public.studies;
  SELECT COUNT(*) INTO media_count FROM public.media;
  SELECT COUNT(*) INTO feedback_count FROM public.feedback;
  SELECT COUNT(*) INTO signoff_count FROM public.signoffs;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'AFTER DELETION:';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Studies: %', study_count;
  RAISE NOTICE 'Media: %', media_count;
  RAISE NOTICE 'Feedback: %', feedback_count;
  RAISE NOTICE 'Signoffs: %', signoff_count;
  RAISE NOTICE '========================================';
  
  IF study_count = 0 AND media_count = 0 AND feedback_count = 0 AND signoff_count = 0 THEN
    RAISE NOTICE '✅ SUCCESS: All studies and related data deleted';
  ELSE
    RAISE WARNING '⚠️  WARNING: Some data may still exist';
  END IF;
END $$;

-- STEP 4: Optional - Clean up storage objects
-- Uncomment the following if you also want to delete media files from storage
-- WARNING: This will delete all files in the 'studies' bucket
/*
-- First, list what will be deleted
SELECT 
  COUNT(*) as file_count,
  pg_size_pretty(SUM((metadata->>'size')::bigint)) as total_size
FROM storage.objects
WHERE bucket_id = 'studies';

-- Then delete (uncomment to execute)
-- DELETE FROM storage.objects WHERE bucket_id = 'studies';
*/

-- STEP 5: Verify preserved data
DO $$
DECLARE
  user_count integer;
  institution_count integer;
  membership_count integer;
  profile_count integer;
BEGIN
  SELECT COUNT(*) INTO user_count FROM auth.users;
  SELECT COUNT(*) INTO institution_count FROM public.institutions;
  SELECT COUNT(*) INTO membership_count FROM public.memberships;
  SELECT COUNT(*) INTO profile_count FROM public.profiles;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'PRESERVED DATA:';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Users: %', user_count;
  RAISE NOTICE 'Institutions: %', institution_count;
  RAISE NOTICE 'Memberships: %', membership_count;
  RAISE NOTICE 'Profiles: %', profile_count;
  RAISE NOTICE '========================================';
END $$;

