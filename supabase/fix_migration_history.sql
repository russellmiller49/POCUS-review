-- Fix migration history: Mark the invalid timestamp migration as reverted
-- This migration has timestamp '20251109' which is invalid format
-- We have a proper migration 20251109000000_set_created_by_default.sql that does the same thing

-- Remove the invalid migration from history
DELETE FROM supabase_migrations.schema_migrations 
WHERE version = '20251109';

-- Verify it's gone
SELECT version, name, inserted_at 
FROM supabase_migrations.schema_migrations 
WHERE version LIKE '20251109%'
ORDER BY version;





