-- Provides a secure way to list approved members (with profile info) for an institution.
-- Used by the mobile app to populate attending drop-downs without exposing profiles table directly.

drop function if exists public.list_institution_members(uuid);

create function public.list_institution_members(target_institution uuid)
returns table (
    user_id uuid,
    full_name text,
    email text,
    role text,
    roles text[]
)
security definer
set search_path = public
language sql
as $$
    select
        m.user_id,
        p.full_name,
        p.email,
        m.role,
        m.roles
    from public.memberships m
    join public.profiles p on p.id = m.user_id
    where m.institution_id = target_institution
      and coalesce(m.role_approved, true) = true;
$$;

grant execute on function public.list_institution_members(uuid) to authenticated;
