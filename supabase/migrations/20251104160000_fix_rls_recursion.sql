-- RLS helper functions must run as the table owner to avoid recursive policy calls.
-- SECURITY DEFINER lets these helpers bypass RLS when they touch protected tables.

create or replace function public.has_admin_role()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.role = 'admin'
  );
$$;

grant execute on function public.has_admin_role() to authenticated;

create or replace function public.is_member_of(inst_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.institution_id = inst_id
  );
$$;

grant execute on function public.is_member_of(uuid) to authenticated;

create or replace function public.has_role(inst_id uuid, target_role text)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.institution_id = inst_id
      and m.role = target_role
  );
$$;

grant execute on function public.has_role(uuid, text) to authenticated;

create or replace function public.can_access_study(sid uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.studies s
    join public.memberships m
      on m.institution_id = s.institution_id
     and m.user_id = auth.uid()
    where s.id = sid
      and (
        s.created_by = auth.uid()
        or m.role in ('attending', 'admin')
      )
  );
$$;

grant execute on function public.can_access_study(uuid) to authenticated;

alter table public.memberships no force row level security;
alter table public.studies no force row level security;
