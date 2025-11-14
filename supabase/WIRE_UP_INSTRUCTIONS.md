# Supabase Wiring Instructions

This document provides step-by-step instructions to wire up Supabase for the per-media feedback updates.

## Prerequisites

- Supabase CLI installed and configured
- Access to your Supabase project (local or remote)
- All existing migrations should be applied

## Step 1: Apply New Migrations

The following migrations need to be applied in order:

### 1.1 Verify Existing Migration
Ensure `20251113120000_add_feedback_media_id.sql` has been applied. This adds:
- `media_id` column to `feedback` table
- Basic RLS policies for per-media feedback

### 1.2 Apply Integrity Migration
Apply the new integrity migration:

```bash
# If using Supabase CLI locally
supabase migration up

# Or manually in Supabase Dashboard SQL Editor
# Copy and paste the contents of:
# supabase/migrations/20251113130000_ensure_feedback_media_integrity.sql
```

This migration adds:
- Check constraint to ensure `media_id` belongs to the same `study_id`
- Enhanced RLS policy with media validation
- Composite index for efficient queries

## Step 2: Verify Setup

Run the verification script to ensure everything is properly configured:

```sql
-- In Supabase Dashboard SQL Editor or via CLI
\i supabase/verify_media_feedback_setup.sql
```

Or copy/paste the contents of `verify_media_feedback_setup.sql` into the SQL Editor.

Expected output:
- ✓ feedback.media_id column exists
- ✓ Foreign key constraint exists
- ✓ Check constraint feedback_media_study_match exists
- ✓ Indexes exist
- ✓ RLS policies exist
- ✓ All existing feedback records have valid media_id references

## Step 3: Test the Setup

### 3.1 Test Insert with media_id

```sql
-- First, get a valid study_id and media_id from your database
-- Then test inserting feedback with media_id
INSERT INTO public.feedback (
    id,
    study_id,
    reviewer_id,
    comments,
    media_id
)
VALUES (
    gen_random_uuid(),
    '<your_study_id>',
    '<your_reviewer_id>',
    'Test per-media feedback',
    '<your_media_id>'
);
```

### 3.2 Test Integrity Constraint

This should fail (media_id from different study):

```sql
-- This should fail with constraint violation
INSERT INTO public.feedback (
    id,
    study_id,
    reviewer_id,
    comments,
    media_id
)
VALUES (
    gen_random_uuid(),
    '<different_study_id>',
    '<your_reviewer_id>',
    'This should fail',
    '<media_id_from_different_study>'
);
```

### 3.3 Test RLS Policies

Test that only authorized users can insert feedback:

```sql
-- As an attending/admin user, this should succeed
-- As a fellow, this should fail (unless they're the reviewer)
-- Check your RLS policies are working correctly
```

## Step 4: Code Integration Verification

### 4.1 Swift Models
Verify the Swift code matches the schema:

- `Feedback` struct in `SupabaseEntities.swift` has `mediaId: UUID?`
- `NewFeedbackRequest` in `StudyService.swift` has `mediaId: UUID?`
- `FeedbackRow` decoder includes `media_id` field

### 4.2 Service Layer
Verify service methods:

- `insertFeedback(_ payload: NewFeedbackRequest)` accepts `mediaId`
- `fetchFeedback(for studyId: UUID)` returns feedback with `mediaId`
- `fetchFeedback(for studyIds: [UUID])` bulk fetches with `mediaId`

### 4.3 View Model
Verify AppViewModel:

- `addMediaComment(for media: Media, ...)` creates feedback with `mediaId`
- `feedbackByStudy` cache includes per-media feedback
- `preloadFeedbackForMyStudies()` loads feedback with `mediaId`

## Step 5: Common Issues and Fixes

### Issue: Migration fails with "column already exists"

**Solution**: The migration uses `ADD COLUMN IF NOT EXISTS`, so it's safe to run multiple times. If you see this error, the column already exists and you can skip to the next migration.

### Issue: RLS policy conflicts

**Solution**: The migrations use `DROP POLICY IF EXISTS` before creating new policies. If you see conflicts:

1. Check existing policies: `SELECT * FROM pg_policies WHERE tablename = 'feedback';`
2. Manually drop conflicting policies if needed
3. Re-run the migration

### Issue: Check constraint fails on existing data

**Solution**: If you have existing feedback with invalid `media_id` references:

```sql
-- Find invalid records
SELECT f.id, f.study_id, f.media_id, m.study_id as media_study_id
FROM public.feedback f
JOIN public.media m ON m.id = f.media_id
WHERE f.media_id IS NOT NULL
  AND f.study_id != m.study_id;

-- Fix invalid records (set media_id to NULL or delete)
UPDATE public.feedback
SET media_id = NULL
WHERE id IN (
    SELECT f.id
    FROM public.feedback f
    JOIN public.media m ON m.id = f.media_id
    WHERE f.media_id IS NOT NULL
      AND f.study_id != m.study_id
);
```

### Issue: Cannot insert feedback with media_id

**Checklist**:
1. User has approved attending/admin/administrator/analyst role
2. User is a member of the study's institution
3. `media_id` (if provided) belongs to the same `study_id`
4. RLS policies are active (not disabled)

## Step 6: Production Deployment

### 6.1 Pre-deployment Checklist

- [ ] All migrations applied and verified
- [ ] Verification script passes
- [ ] Test inserts/updates work correctly
- [ ] RLS policies tested with different user roles
- [ ] Existing data validated (no constraint violations)

### 6.2 Deployment Steps

1. **Backup database** (always!)
2. Apply migrations in order:
   ```bash
   supabase db push
   # or
   supabase migration up
   ```
3. Run verification script
4. Test with real user accounts
5. Monitor for any errors in logs

### 6.3 Rollback Plan

If issues occur:

1. The `media_id` column is nullable, so existing code will continue to work
2. You can temporarily disable the check constraint:
   ```sql
   ALTER TABLE public.feedback
   DROP CONSTRAINT IF EXISTS feedback_media_study_match;
   ```
3. Re-enable when ready:
   ```sql
   ALTER TABLE public.feedback
   ADD CONSTRAINT feedback_media_study_match
   CHECK (
       media_id IS NULL OR EXISTS (
           SELECT 1
           FROM public.media m
           WHERE m.id = feedback.media_id
             AND m.study_id = feedback.study_id
       )
   );
   ```

## Step 7: Monitoring

After deployment, monitor:

1. **Error logs**: Check for constraint violations or RLS policy failures
2. **Query performance**: Monitor slow queries on `feedback` table
3. **Data integrity**: Periodically verify `media_id` references are valid

```sql
-- Periodic integrity check
SELECT COUNT(*) as invalid_count
FROM public.feedback f
WHERE f.media_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM public.media m
      WHERE m.id = f.media_id
        AND m.study_id = f.study_id
  );
```

## Additional Resources

- `MEDIA_FEEDBACK_SETUP.md` - Detailed schema documentation
- `verify_media_feedback_setup.sql` - Verification script
- Migration files in `supabase/migrations/`

## Support

If you encounter issues:

1. Check the verification script output
2. Review RLS policies: `SELECT * FROM pg_policies WHERE tablename = 'feedback';`
3. Check constraint definitions: `\d+ public.feedback` in psql
4. Review Supabase logs for detailed error messages




