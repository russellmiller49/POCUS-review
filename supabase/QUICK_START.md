# Quick Start: Wire Up Per-Media Feedback

## TL;DR

1. Apply the new migration: `20251113130000_ensure_feedback_media_integrity.sql`
2. Run verification: `verify_media_feedback_setup.sql`
3. Test with your app

## Commands

```bash
# Apply migrations
supabase migration up

# Or in Supabase Dashboard SQL Editor, run:
# - supabase/migrations/20251113130000_ensure_feedback_media_integrity.sql
# - supabase/verify_media_feedback_setup.sql
```

## What Changed

- ✅ `feedback.media_id` column already exists (from previous migration)
- ✅ Added data integrity constraint (media_id must match study_id)
- ✅ Enhanced RLS policies with media validation
- ✅ Added composite index for performance

## Verification

Run `verify_media_feedback_setup.sql` - all checks should pass.

## Need Help?

See `WIRE_UP_INSTRUCTIONS.md` for detailed steps and troubleshooting.




