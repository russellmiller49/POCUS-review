-- Fix RLS policy issue by setting default value for created_by
-- This allows the app to insert studies without explicitly providing created_by
-- The value will automatically be set to the current user's ID (auth.uid())

alter table public.studies
  alter column created_by set default auth.uid();
