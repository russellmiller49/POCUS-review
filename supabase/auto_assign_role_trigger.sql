-- Auto-Assign Default Role to New Users
-- This trigger automatically assigns a 'fellow' role to new users when they sign up
-- Run this in Supabase SQL Editor if you want automatic role assignment

-- ============================================
-- Create Function to Auto-Assign Default Role
-- ============================================
CREATE OR REPLACE FUNCTION public.assign_default_role()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    default_institution_id uuid;
BEGIN
    -- Get the first/default institution (or use a specific slug)
    SELECT id INTO default_institution_id 
    FROM public.institutions 
    WHERE slug = 'default-institution'  -- Change to your default institution slug
    ORDER BY created_at ASC 
    LIMIT 1;
    
    -- If no specific institution found, use the first one
    IF default_institution_id IS NULL THEN
        SELECT id INTO default_institution_id 
        FROM public.institutions 
        ORDER BY created_at ASC 
        LIMIT 1;
    END IF;
    
    -- Assign 'fellow' role by default (change to 'attending' or 'admin' if preferred)
    IF default_institution_id IS NOT NULL THEN
        INSERT INTO public.memberships (user_id, institution_id, role)
        VALUES (NEW.id, default_institution_id, 'fellow')
        ON CONFLICT (user_id, institution_id) DO NOTHING;
    END IF;
    
    RETURN NEW;
END;
$$;

-- ============================================
-- Create Trigger (runs after profile is created)
-- ============================================
DROP TRIGGER IF EXISTS assign_default_role_trigger ON public.profiles;

CREATE TRIGGER assign_default_role_trigger
AFTER INSERT ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.assign_default_role();

-- ============================================
-- Grant Permissions
-- ============================================
GRANT EXECUTE ON FUNCTION public.assign_default_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_default_role() TO service_role;

-- ============================================
-- Test: Verify trigger works
-- ============================================
-- After a new user signs up, check if they got a role:
-- SELECT * FROM public.memberships ORDER BY created_at DESC LIMIT 5;
















