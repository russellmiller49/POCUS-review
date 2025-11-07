-- Auto-Assign Default Role to New Users
-- This trigger automatically assigns a 'fellow' role to new users when they sign up
-- Admins can manually promote users to 'attending' or 'admin' later

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
    -- Try to find a default institution by slug first
    SELECT id INTO default_institution_id 
    FROM public.institutions 
    WHERE slug = 'default-institution'
    LIMIT 1;
    
    -- If no 'default-institution' exists, use the first institution
    IF default_institution_id IS NULL THEN
        SELECT id INTO default_institution_id 
        FROM public.institutions 
        ORDER BY created_at ASC 
        LIMIT 1;
    END IF;
    
    -- If still no institution exists, create one automatically
    IF default_institution_id IS NULL THEN
        INSERT INTO public.institutions (slug, name, settings)
        VALUES ('default-institution', 'Default Institution', '{}'::jsonb)
        ON CONFLICT (slug) DO NOTHING
        RETURNING id INTO default_institution_id;
        
        -- If insert didn't return id (conflict), fetch it
        IF default_institution_id IS NULL THEN
            SELECT id INTO default_institution_id 
            FROM public.institutions 
            WHERE slug = 'default-institution'
            LIMIT 1;
        END IF;
    END IF;
    
    -- Assign 'fellow' role by default to new users (only if institution exists)
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


