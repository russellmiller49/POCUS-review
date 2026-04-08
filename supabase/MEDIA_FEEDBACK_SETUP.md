# Per-Media Feedback Setup

This document describes the Supabase schema changes that support per-media feedback functionality.

## Overview

The app now supports attaching feedback to specific media items (images/videos) within a study, in addition to study-level feedback. This allows attendings to provide targeted comments on individual assets.

## Schema Changes

### 1. Feedback Table Enhancement

**Migration**: `20251113120000_add_feedback_media_id.sql`

- Added `media_id` column (UUID, nullable) to `public.feedback` table
- Foreign key constraint: `media_id` references `public.media(id)` with `ON DELETE CASCADE`
- Index: `idx_feedback_media_id` on `media_id` for query performance

### 2. Data Integrity

**Migration**: `20251113130000_ensure_feedback_media_integrity.sql`

- Check constraint: Ensures that if `media_id` is provided, it belongs to the same `study_id`
- Composite index: `idx_feedback_study_media` on `(study_id, media_id)` for efficient queries
- Enhanced RLS policy: Validates media ownership during INSERT

## RLS Policies

### INSERT Policy: `attending inserts feedback`

Allows authenticated users with approved attending/admin/administrator/analyst roles to insert feedback:
- Must be a member of the study's institution
- Role must be approved (`role_approved = true`)
- If `media_id` is provided, it must belong to the same `study_id`

### UPDATE Policy: `attending updates feedback`

Allows reviewers to update their own feedback, or admins to update any feedback.

### SELECT Policy: `select feedback if authorized`

Allows users to read feedback if they can access the parent study (via `can_access_study` helper) or if they created the study.

## Code Integration

### Swift Models

- `Feedback` struct includes optional `mediaId: UUID?` (line 113 in `SupabaseEntities.swift`)
- `NewFeedbackRequest` includes optional `mediaId: UUID?` (line 274 in `StudyService.swift`)

### Service Layer

- `StudyService.insertFeedback()` accepts `NewFeedbackRequest` with optional `mediaId`
- `AppViewModel.addMediaComment()` creates feedback with `mediaId` set (line 607-635)

## Verification

Run the verification script to ensure all components are properly configured:

```sql
\i supabase/verify_media_feedback_setup.sql
```

Or in Supabase Dashboard:
1. Go to SQL Editor
2. Copy and paste the contents of `verify_media_feedback_setup.sql`
3. Run the query

## Migration Order

The migrations should be applied in this order:

1. `20251113120000_add_feedback_media_id.sql` - Adds column and basic RLS
2. `20251113130000_ensure_feedback_media_integrity.sql` - Adds integrity constraints

## Testing

To test the setup:

1. **Create a study with media**:
   ```sql
   -- Create study
   INSERT INTO public.studies (id, institution_id, created_by, exam_type, status)
   VALUES (gen_random_uuid(), '<institution_id>', '<user_id>', 'cardiac', 'submitted');
   
   -- Add media
   INSERT INTO public.media (id, study_id, kind, storage_path, content_type, status)
   VALUES (gen_random_uuid(), '<study_id>', 'image', 'studies/<study_id>/image.jpg', 'image/jpeg', 'clean');
   ```

2. **Add per-media feedback**:
   ```sql
   INSERT INTO public.feedback (id, study_id, reviewer_id, comments, media_id)
   VALUES (gen_random_uuid(), '<study_id>', '<reviewer_id>', 'Great image quality', '<media_id>');
   ```

3. **Verify integrity** (should fail if media_id doesn't match study_id):
   ```sql
   -- This should fail:
   INSERT INTO public.feedback (id, study_id, reviewer_id, comments, media_id)
   VALUES (gen_random_uuid(), '<different_study_id>', '<reviewer_id>', 'Test', '<media_id>');
   ```

## Troubleshooting

### Issue: Cannot insert feedback with media_id

**Check**:
1. User has approved attending/admin role in the institution
2. `media_id` belongs to the same `study_id`
3. RLS policies are active: `SELECT * FROM pg_policies WHERE tablename = 'feedback';`

### Issue: Feedback not showing in queries

**Check**:
1. User has access to the parent study (via `can_access_study`)
2. SELECT policy is active
3. Indexes exist for performance

### Issue: Migration conflicts

If you see errors about existing policies or constraints:
- The migrations use `DROP POLICY IF EXISTS` and `ADD COLUMN IF NOT EXISTS`
- Run migrations in order
- Check migration history: `SELECT * FROM supabase_migrations.schema_migrations ORDER BY version;`

## Related Files

- `POCUS_Mentor/POCUS_Mentor/Models/SupabaseEntities.swift` - Swift models
- `POCUS_Mentor/POCUS_Mentor/Services/StudyService.swift` - Service layer
- `POCUS_Mentor/POCUS_Mentor/ViewModels/AppViewModel.swift` - View model with `addMediaComment()`




