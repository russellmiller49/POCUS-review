-- Signup Enhancements: Name, Institution Selection, Role, PGY Year, and Approval Workflow
-- This migration adds support for user signup with institution selection, role choice, and approval workflow

-- ============================================
-- 1. Ensure profiles table has full_name
-- ============================================
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'profiles' 
        AND column_name = 'full_name'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN full_name text;
    END IF;
END $$;

-- ============================================
-- 2. Add PGY year and approval status to memberships
-- ============================================
ALTER TABLE public.memberships 
ADD COLUMN IF NOT EXISTS pgy_year text CHECK (pgy_year IN ('PGY-4', 'PGY-5', 'PGY-6')),
ADD COLUMN IF NOT EXISTS role_approved boolean NOT NULL DEFAULT true,
ADD COLUMN IF NOT EXISTS role_requested_at timestamptz;

-- Update existing memberships to be approved
UPDATE public.memberships SET role_approved = true WHERE role_approved IS NULL;

-- ============================================
-- 3. Create Institutions (Naval Medical Center San Diego and UCSD)
-- ============================================
INSERT INTO public.institutions (slug, name, settings)
VALUES 
    ('naval-medical-center-san-diego', 'Naval Medical Center San Diego', '{}'::jsonb),
    ('university-of-california-san-diego', 'University of California San Diego', '{}'::jsonb)
ON CONFLICT (slug) DO NOTHING;

-- ============================================
-- 4. Update auto-assignment trigger to handle signup flow
-- ============================================
-- Disable the old trigger that auto-assigns roles
DROP TRIGGER IF EXISTS assign_default_role_trigger ON public.profiles;

-- Create new function that handles signup with role selection
CREATE OR REPLACE FUNCTION public.handle_new_user_signup()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    -- Profile is created, but membership will be created by the app
    -- This function can be used for other profile setup if needed
    RETURN NEW;
END;
$$;

-- Create trigger for profile creation (for future use)
CREATE TRIGGER handle_new_user_signup_trigger
AFTER INSERT ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user_signup();

-- ============================================
-- 5. Grant permissions
-- ============================================
GRANT EXECUTE ON FUNCTION public.handle_new_user_signup() TO authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user_signup() TO service_role;

-- ============================================
-- 6. Update RLS policies to allow users to create their own membership requests
-- ============================================
-- Allow users to insert their own membership (for signup)
DROP POLICY IF EXISTS "users can request membership" ON public.memberships;
CREATE POLICY "users can request membership" ON public.memberships
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- Allow users to read their own memberships (including pending)
DROP POLICY IF EXISTS "users can read own memberships" ON public.memberships;
CREATE POLICY "users can read own memberships" ON public.memberships
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- ============================================
-- 7. Create function to approve role requests (for admins)
-- ============================================
CREATE OR REPLACE FUNCTION public.approve_role_request(
    target_user_id uuid,
    target_institution_id uuid
)
RETURNS void
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    -- Check if caller is admin
    IF NOT EXISTS (
        SELECT 1 FROM public.memberships
        WHERE user_id = auth.uid()
        AND institution_id = target_institution_id
        AND role = 'admin'
        AND role_approved = true
    ) THEN
        RAISE EXCEPTION 'Only admins can approve role requests';
    END IF;
    
    -- Approve the role
    UPDATE public.memberships
    SET role_approved = true,
        role_requested_at = COALESCE(role_requested_at, now())
    WHERE user_id = target_user_id
    AND institution_id = target_institution_id
    AND role_approved = false;
END;
$$;

GRANT EXECUTE ON FUNCTION public.approve_role_request(uuid, uuid) TO authenticated;


