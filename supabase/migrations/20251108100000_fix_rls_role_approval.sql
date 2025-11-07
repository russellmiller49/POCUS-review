-- Fix RLS policies to check role_approved status
-- This ensures that only approved memberships can create studies and access resources

-- ============================================
-- Update helper functions to check role_approved
-- ============================================

-- Update is_member_of to only return true for approved memberships
create or replace function public.is_member_of(inst_id uuid)
returns boolean language sql stable as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.institution_id = inst_id
      and (m.role_approved = true or m.role_approved is null) -- null means approved (backward compatibility)
  );
$$;

-- Update has_role to check both role column and roles array, AND require approval
create or replace function public.has_role(inst_id uuid, target_role text)
returns boolean language sql stable as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.institution_id = inst_id
      and (m.role_approved = true or m.role_approved is null) -- null means approved (backward compatibility)
      and (
        m.role = target_role
        or (m.roles is not null and target_role = any(m.roles))
      )
  );
$$;

-- Update has_admin_role to require approval
create or replace function public.has_admin_role()
returns boolean language sql stable as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and (m.role_approved = true or m.role_approved is null) -- null means approved (backward compatibility)
      and (
        m.role = 'admin'
        or (m.roles is not null and 'admin' = any(m.roles))
      )
  );
$$;

-- Update can_access_study to require approved memberships
create or replace function public.can_access_study(sid uuid)
returns boolean language sql stable as $$
  select exists (
    select 1
    from public.studies s
    join public.memberships m
      on m.institution_id = s.institution_id
     and m.user_id = auth.uid()
     and (m.role_approved = true or m.role_approved is null) -- null means approved (backward compatibility)
    where s.id = sid
      and (
        s.created_by = auth.uid()
        or m.role = any(array['admin','attending'])
        or (m.roles && array['admin'::text, 'attending'::text])
      )
  );
$$;

-- ============================================
-- Update RLS policies to ensure they use approved memberships
-- ============================================

-- The existing "member inserts own studies" policy already uses is_member_of,
-- which now checks role_approved, so it should work correctly.

-- However, let's also update the institutions read policy to check approval
drop policy if exists "read own institution" on public.institutions;
create policy "read own institution"
on public.institutions for select
to authenticated
using (
  public.is_member_of(institutions.id) or public.has_admin_role()
);

-- Update memberships read policy to only show approved memberships to users
drop policy if exists "read own membership" on public.memberships;
create policy "read own membership"
on public.memberships for select
to authenticated
using (
  (user_id = auth.uid() and (role_approved = true or role_approved is null))
  or public.has_admin_role()
);

