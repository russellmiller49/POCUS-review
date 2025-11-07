-- Update helper predicates so RLS respects both the legacy `role` column
-- and the new `roles` array (which can store multiple approved roles per
-- membership). Without this, newly onboarded users whose memberships only
-- populate the array cannot pass `public.has_role(...)`, causing study
-- creation to fail even though they are fellows.

create or replace function public.has_role(inst_id uuid, target_role text)
returns boolean language sql stable as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.institution_id = inst_id
      and (
        m.role = target_role
        or (m.roles is not null and target_role = any(m.roles))
      )
  );
$$;

create or replace function public.has_admin_role()
returns boolean language sql stable as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and (
        m.role = 'admin'
        or (m.roles is not null and 'admin' = any(m.roles))
      )
  );
$$;

create or replace function public.can_access_study(sid uuid)
returns boolean language sql stable as $$
  select exists (
    select 1
    from public.studies s
    join public.memberships m
      on m.institution_id = s.institution_id
     and m.user_id = auth.uid()
    where s.id = sid
      and (
        s.created_by = auth.uid()
        or m.role = any(array['admin','attending'])
        or (m.roles && array['admin'::text, 'attending'::text])
      )
  );
$$;
