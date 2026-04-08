# Starting Local Supabase

## Prerequisites
- Docker Desktop must be running

## Steps

1. **Start Docker Desktop** (if not already running)

2. **Start Supabase locally**:
   ```bash
   cd /Users/russellmiller/Projects/POCUS_APP/POCUS_Mentor
   supabase start
   ```

3. **Apply migrations**:
   ```bash
   supabase migration up
   ```

4. **Verify setup**:
   ```bash
   # Run verification script
   psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -f supabase/verify_media_feedback_setup.sql
   ```

## Stop Local Supabase

When done:
```bash
supabase stop
```

## Note

If you're working with a remote project, it's easier to use the Dashboard SQL Editor (see `APPLY_TO_REMOTE.sql`).




