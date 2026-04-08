-- === INSTITUTIONS ===
-- Users can read institutions they are members of
drop policy if exists "read own institution" on public.institutions;
create policy "read own institution"
on public.institutions for select
to authenticated
using (public.is_member_of(institutions.id) or public.has_admin_role());

-- Admin can manage institutions
drop policy if exists "admin manage institutions" on public.institutions;
create policy "admin manage institutions"
on public.institutions for all
to authenticated
using (public.has_admin_role())
with check (public.has_admin_role());

-- === MEMBERSHIPS ===
-- Users can read their own memberships and admins can read all
drop policy if exists "read own membership" on public.memberships;
create policy "read own membership"
on public.memberships for select
to authenticated
using (user_id = auth.uid() or public.has_admin_role());

-- Admin can manage memberships
drop policy if exists "admin manage memberships" on public.memberships;
create policy "admin manage memberships"
on public.memberships for all
to authenticated
using (public.has_admin_role())
with check (public.has_admin_role());

-- === STUDIES ===
-- Fellows create studies they own (must be member of institution)
drop policy if exists "fellow inserts own studies" on public.studies;
create policy "fellow inserts own studies"
on public.studies for insert
to authenticated
with check (
  created_by = auth.uid()
  and public.is_member_of(institution_id)
  and (public.has_role(institution_id, 'fellow') or public.has_admin_role())
);

-- Users can select studies they have access to
drop policy if exists "select studies if authorized" on public.studies;
create policy "select studies if authorized"
on public.studies for select
to authenticated
using (public.can_access_study(id));

-- Allow updates by owner (fellow) and assigned attending; admin override
drop policy if exists "update studies if authorized" on public.studies;
create policy "update studies if authorized"
on public.studies for update
to authenticated
using (public.can_access_study(id))
with check (public.can_access_study(id));

-- === MEDIA ===
-- Insert media only for studies the user owns (fellow) or admin
drop policy if exists "insert media for own study" on public.media;
create policy "insert media for own study"
on public.media for insert
to authenticated
with check (
  exists (
    select 1 from public.studies s
    where s.id = media.study_id
      and (s.created_by = auth.uid() or public.has_admin_role())
  )
);

-- Select media if user can access the parent study
drop policy if exists "select media if authorized" on public.media;
create policy "select media if authorized"
on public.media for select
to authenticated
using (public.can_access_study(study_id));

-- === FEEDBACK ===
-- Insert feedback: attending assigned to the study or admin
drop policy if exists "attending inserts feedback" on public.feedback;
create policy "attending inserts feedback"
on public.feedback for insert
to authenticated
with check (
  (public.has_admin_role() or exists (
    select 1 from public.studies s
    join public.memberships m on m.institution_id = s.institution_id and m.user_id = auth.uid()
    where s.id = feedback.study_id
      and (m.role = 'attending' or m.role = 'admin')
  ))
);

-- Read feedback if user can access the parent study
drop policy if exists "select feedback if authorized" on public.feedback;
create policy "select feedback if authorized"
on public.feedback for select
to authenticated
using (public.can_access_study(study_id));

-- === SIGNOFFS ===
-- Attendings can create signoffs for assigned studies
drop policy if exists "attending inserts signoff" on public.signoffs;
create policy "attending inserts signoff"
on public.signoffs for insert
to authenticated
with check (
  public.has_admin_role() or exists (
    select 1 from public.studies s
    join public.memberships m on m.institution_id = s.institution_id and m.user_id = auth.uid()
    where s.id = signoffs.study_id
      and (m.role = 'attending' or m.role = 'admin')
  )
);

-- Users can read signoffs for studies they can access
drop policy if exists "select signoffs if authorized" on public.signoffs;
create policy "select signoffs if authorized"
on public.signoffs for select
to authenticated
using (public.can_access_study(study_id));

-- === STORAGE.OBJECTS (bucket pocus-media) ===
-- READ (to generate signed URLs, clients need SELECT on storage.objects)
drop policy if exists "read media objects if authorized" on storage.objects;
create policy "read media objects if authorized"
on storage.objects for select
to authenticated
using (
  bucket_id = 'pocus-media'
  and exists (
    select 1 from public.media m
    where m.storage_path = storage.objects.name
      and public.can_access_study(m.study_id)
  )
);

-- WRITE: allow fellows/admin to upload into studies/<study_id>/...
drop policy if exists "insert media objects if authorized" on storage.objects;
create policy "insert media objects if authorized"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'pocus-media'
  and exists (
    select 1 from public.studies s
    where s.id = public.uuid_from_path(name)
      and (s.created_by = auth.uid() or public.has_admin_role())
  )
);

-- Allow deletes by owner/attending/admin
drop policy if exists "delete media objects if authorized" on storage.objects;
create policy "delete media objects if authorized"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'pocus-media'
  and exists (
    select 1 from public.media m
    where m.storage_path = storage.objects.name
      and public.can_access_study(m.study_id)
  )
);

