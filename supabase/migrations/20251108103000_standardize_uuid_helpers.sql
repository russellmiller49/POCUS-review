-- 0) Preflight (read-only diagnostics)
-- List all helper overloads currently defined
select
  n.nspname  as schema_name,
  p.proname  as function_name,
  pg_catalog.pg_get_function_identity_arguments(p.oid) as args
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('can_access_study','is_member_of','has_role','has_admin_role')
order by function_name, args;

-- Find policies that invoke helper functions (so we can verify after normalization)
with policies as (
  select n.nspname as schema_name,
         c.relname as table_name,
         p.polname as policy_name,
         p.polcmd   as cmd,
         p.polpermissive as permissive,
         pg_get_expr(p.polqual, p.polrelid)      as using_expr,
         pg_get_expr(p.polwithcheck, p.polrelid) as with_check_expr
  from pg_policy p
  join pg_class c on c.oid = p.polrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname not in ('pg_catalog','information_schema')
)
select *
from policies
where using_expr ilike '%can_access_study(%'
   or with_check_expr ilike '%can_access_study(%'
   or using_expr ilike '%is_member_of(%'
   or with_check_expr ilike '%is_member_of(%'
order by schema_name, table_name, policy_name;

-- 1) Transactional migration for UUID-only helpers/policies
begin;

-- 1A) Canonical helper definitions (UUID-only ids)
create or replace function public.is_member_of(inst_id uuid)
returns boolean
language sql
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.institution_id = inst_id
      and coalesce(m.role_approved, true) = true
  );
$$;

create or replace function public.has_role(inst_id uuid, target_role text)
returns boolean
language sql
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.institution_id = inst_id
      and coalesce(m.role_approved, true) = true
      and (
        lower(m.role) = lower(target_role)
        or exists (
          select 1
          from unnest(coalesce(m.roles, '{}'::text[])) r
          where lower(r) = lower(target_role)
        )
      )
  );
$$;

create or replace function public.has_admin_role()
returns boolean
language sql
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and coalesce(m.role_approved, true) = true
      and (
        lower(m.role) = 'admin'
        or exists (
          select 1
          from unnest(coalesce(m.roles, '{}'::text[])) r
          where lower(r) = 'admin'
        )
      )
  );
$$;

create or replace function public.has_admin_or_attending(inst_id uuid)
returns boolean
language sql
stable
set search_path = public
as $$
  select public.has_role(inst_id, 'admin') or public.has_role(inst_id, 'attending');
$$;

create or replace function public.can_access_study(sid uuid)
returns boolean
language sql
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.studies s
    where s.id = sid
      and (
        s.created_by = auth.uid()
        or public.is_member_of(s.institution_id)
        or public.has_admin_or_attending(s.institution_id)
        or public.has_admin_role()
      )
  );
$$;

create or replace function public.uuid_from_path(name text)
returns uuid
language sql
stable
set search_path = public
as $$
  select nullif(split_part(name, '/', 3), '')::uuid;
$$;

-- 1B) Normalize policies to call helpers with UUID arguments
do $$
declare
  r record;
  new_using text;
  new_check text;
begin
  for r in (
    select p.oid as pol_oid,
           n.nspname as schema_name,
           c.relname as table_name,
           p.polname as policy_name,
           p.polcmd,
           pg_get_expr(p.polqual, p.polrelid)      as using_expr,
           pg_get_expr(p.polwithcheck, p.polrelid) as with_check_expr
    from pg_policy p
    join pg_class c on c.oid = p.polrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname not in ('pg_catalog','information_schema')
  ) loop
    new_using := r.using_expr;
    new_check := r.with_check_expr;

    if new_using is not null then
      new_using := regexp_replace(new_using, '\bcan_access_study_v2\s*\(', 'can_access_study(', 'gi');
      new_using := regexp_replace(new_using, '\bis_member_of_v2\s*\(', 'is_member_of(', 'gi');
      new_using := regexp_replace(new_using,
                   '\bcan_access_study\s*\(\s*([^)]+?)\s*\)',
                   'can_access_study((\1)::uuid)', 'gi');
      new_using := regexp_replace(new_using,
                   '\bis_member_of\s*\(\s*([^)]+?)\s*\)',
                   'is_member_of((\1)::uuid)', 'gi');
      new_using := regexp_replace(new_using, '::\s*text\b', '', 'gi');
    end if;

    if new_check is not null then
      new_check := regexp_replace(new_check, '\bcan_access_study_v2\s*\(', 'can_access_study(', 'gi');
      new_check := regexp_replace(new_check, '\bis_member_of_v2\s*\(', 'is_member_of(', 'gi');
      new_check := regexp_replace(new_check,
                   '\bcan_access_study\s*\(\s*([^)]+?)\s*\)',
                   'can_access_study((\1)::uuid)', 'gi');
      new_check := regexp_replace(new_check,
                   '\bis_member_of\s*\(\s*([^)]+?)\s*\)',
                   'is_member_of((\1)::uuid)', 'gi');
      new_check := regexp_replace(new_check, '::\s*text\b', '', 'gi');
    end if;

    if r.polcmd in ('r','d') and new_using is distinct from r.using_expr then
      execute format(
        'alter policy %I on %I.%I using (%s)',
        r.policy_name, r.schema_name, r.table_name, coalesce(new_using, 'true')
      );
    elsif r.polcmd = 'a' and new_check is distinct from r.with_check_expr then
      execute format(
        'alter policy %I on %I.%I with check (%s)',
        r.policy_name, r.schema_name, r.table_name, coalesce(new_check, 'true')
      );
    elsif r.polcmd = 'w' and (new_using is distinct from r.using_expr or new_check is distinct from r.with_check_expr) then
      execute format(
        'alter policy %I on %I.%I using (%s) with check (%s)',
        r.policy_name, r.schema_name, r.table_name,
        coalesce(new_using, 'true'),
        coalesce(new_check, 'true')
      );
    end if;
  end loop;
end$$;

-- 1C) Remove legacy text overloads now that everything is UUID-normalized
do $$
declare
  fn text;
begin
  foreach fn in array array['can_access_study', 'is_member_of'] loop
    execute format('drop function if exists public.%I(text);', fn);
    execute format('drop function if exists public.%I(text);', fn || '_v2');
  end loop;
end$$;

-- 1D) Supporting indexes for policy performance (idempotent)
create index if not exists memberships_user_inst_approved_idx
  on public.memberships (user_id, institution_id)
  where coalesce(role_approved, true) = true;

create index if not exists memberships_user_inst_role_approved_idx
  on public.memberships (user_id, institution_id, role)
  where coalesce(role_approved, true) = true;

create index if not exists studies_institution_id_idx on public.studies (institution_id);
create index if not exists studies_created_by_idx     on public.studies (created_by);

commit;

-- 2) Post-migration assertions
-- A) Ensure only UUID helpers remain
select
  n.nspname as schema_name,
  p.proname as function_name,
  pg_catalog.pg_get_function_identity_arguments(p.oid) as args
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('can_access_study','is_member_of')
order by function_name, args;

-- B) Ensure no lingering _v2 calls or ::text casts in policies
with policies as (
  select n.nspname as schema_name,
         c.relname as table_name,
         p.polname as policy_name,
         pg_get_expr(p.polqual, p.polrelid)      as using_expr,
         pg_get_expr(p.polwithcheck, p.polrelid) as with_check_expr
  from pg_policy p
  join pg_class c on c.oid = p.polrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname not in ('pg_catalog','information_schema')
)
select *
from policies
where using_expr  ~* '\bcan_access_study_v2\b|\bis_member_of_v2\b|::\s*text\b'
   or with_check_expr ~* '\bcan_access_study_v2\b|\bis_member_of_v2\b|::\s*text\b'
order by schema_name, table_name, policy_name;

-- C) View sanity check (best-effort)
do $$
declare
  r record;
begin
  for r in (
    select n.nspname schema_name,
           c.relname view_name,
           c.relkind
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where c.relkind in ('v','m')
      and n.nspname not in ('pg_catalog','information_schema')
  ) loop
    begin
      execute format('select 1 from %I.%I limit 1;', r.schema_name, r.view_name);
    exception when others then
      raise notice 'View %.% (%): %', r.schema_name, r.view_name, r.relkind, SQLERRM;
    end;
  end loop;
end$$;
