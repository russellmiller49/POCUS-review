-- Generic updated_at trigger
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end; $$;

-- Apply updated_at triggers
drop trigger if exists trig_touch_institutions on public.institutions;
create trigger trig_touch_institutions
before update on public.institutions
for each row execute function public.touch_updated_at();

drop trigger if exists trig_touch_memberships on public.memberships;
create trigger trig_touch_memberships
before update on public.memberships
for each row execute function public.touch_updated_at();

drop trigger if exists trig_touch_studies on public.studies;
create trigger trig_touch_studies
before update on public.studies
for each row execute function public.touch_updated_at();

-- Helper: Check if user has a specific role in an institution
create or replace function public.has_role(inst_id uuid, target_role text)
returns boolean language sql stable as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.institution_id = inst_id
      and m.role = target_role
  );
$$;

-- Helper: Check if user is a member of an institution (any role)
create or replace function public.is_member_of(inst_id uuid)
returns boolean language sql stable as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.institution_id = inst_id
  );
$$;

-- Helper: Check admin role (works across institutions for admin override)
create or replace function public.has_admin_role()
returns boolean language sql stable as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.role = 'admin'
  );
$$;

-- Access check: Can user access a study?
create or replace function public.can_access_study(sid uuid)
returns boolean language sql stable as $$
  select exists (
    select 1 
    from public.studies s
    join public.memberships m on m.institution_id = s.institution_id and m.user_id = auth.uid()
    where s.id = sid
      and (
        s.created_by = auth.uid()  -- Fellow owns the study
        or m.role = 'admin'  -- Admin override
        or m.role = 'attending'  -- Attendings can access studies in their institution
      )
  );
$$;

-- Safe parser for study_id from storage path "studies/<uuid>/..."
create or replace function public.uuid_from_path(name text)
returns uuid language plpgsql immutable as $$
declare
  seg text;
  out_uuid uuid;
begin
  -- e.g., 'studies/0f1c...-.../file.mov' -> second segment is study_id
  seg := split_part(name, '/', 2);
  begin
    out_uuid := seg::uuid;
  exception when invalid_text_representation then
    return null;
  end;
  return out_uuid;
end; $$;

