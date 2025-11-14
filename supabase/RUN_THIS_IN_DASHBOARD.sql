-- ============================================
-- Fix Migration History - Run in Supabase Dashboard
-- ============================================
-- 
-- Instructions:
-- 1. Go to: https://supabase.com/dashboard/project/tqnhxlwvkkswuckszlee/sql/new
-- 2. Copy and paste everything below
-- 3. Click "Run" or press Cmd+Enter
-- 4. Verify the results show the migration is removed
-- 5. Then go back to terminal and run: supabase db push
-- ============================================

-- First, let's check what columns exist in the table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'supabase_migrations' 
  AND table_name = 'schema_migrations';

-- Remove the invalid migration from history
-- This migration has timestamp '20251109' which is invalid format
DELETE FROM supabase_migrations.schema_migrations 
WHERE version = '20251109';

-- Verify it's gone and show remaining 20251109 migrations
-- (Using * to see all columns since we don't know the exact column names)
SELECT * 
FROM supabase_migrations.schema_migrations 
WHERE version LIKE '20251109%'
ORDER BY version;

-- Expected result: Should only show 20251109000000 (the valid one)
