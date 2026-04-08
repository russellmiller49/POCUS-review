-- Fix stack depth limit exceeded error
-- All RLS helper functions must use SECURITY DEFINER to bypass RLS
-- when querying protected tables, preventing infinite recursion

-- Fix is_member_of
CREATE OR REPLACE FUNCTION public.is_member_of(inst_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.institution_id = inst_id
      and (m.role_approved = true or m.role_approved is null)
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_member_of(uuid) TO authenticated;

-- Fix has_role
CREATE OR REPLACE FUNCTION public.has_role(inst_id uuid, target_role text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.institution_id = inst_id
      and (m.role_approved = true or m.role_approved is null)
      and (
        m.role = target_role
        or (m.roles is not null and target_role = any(m.roles))
      )
  );
$$;

GRANT EXECUTE ON FUNCTION public.has_role(uuid, text) TO authenticated;

-- Fix has_admin_role
CREATE OR REPLACE FUNCTION public.has_admin_role()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and (m.role_approved = true or m.role_approved is null)
      and (
        m.role = 'admin'
        or (m.roles is not null and 'admin' = any(m.roles))
      )
  );
$$;

GRANT EXECUTE ON FUNCTION public.has_admin_role() TO authenticated;

-- Fix can_access_study
CREATE OR REPLACE FUNCTION public.can_access_study(sid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  select exists (
    select 1
    from public.studies s
    join public.memberships m
      on m.institution_id = s.institution_id
     and m.user_id = auth.uid()
     and (m.role_approved = true or m.role_approved is null)
    where s.id = sid
      and (
        s.created_by = auth.uid()
        or m.role = any(array['admin','attending'])
        or (m.roles && array['admin'::text, 'attending'::text])
      )
  );
$$;

GRANT EXECUTE ON FUNCTION public.can_access_study(uuid) TO authenticated;













