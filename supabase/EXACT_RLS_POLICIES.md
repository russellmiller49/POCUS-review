# Exact RLS Policy Definitions

This document contains the exact RLS policy definitions for all tables as they currently exist in the database.

## INSTITUTIONS

### Policy: "public read institutions"
**Purpose:** Allow public (unauthenticated) access to institution list for onboarding
```sql
create policy "public read institutions"
on public.institutions
for select
to public
using (true);
```

### Policy: "read own institution"
**Purpose:** Allow authenticated users to read institutions they are members of
```sql
create policy "read own institution"
on public.institutions for select
to authenticated
using (
  public.is_member_of(institutions.id) or public.has_admin_role()
);
```

### Policy: "admin manage institutions"
**Purpose:** Allow admins to manage (INSERT/UPDATE/DELETE) institutions
```sql
create policy "admin manage institutions"
on public.institutions for all
to authenticated
using (public.has_admin_role())
with check (public.has_admin_role());
```

---

## MEDIA

### Policy: "insert media for own study"
**Purpose:** Allow fellows to insert media for studies they created, or admins for any study
```sql
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
```

### Policy: "select media if authorized"
**Purpose:** Allow users to select media if they can access the parent study
```sql
create policy "select media if authorized"
on public.media for select
to authenticated
using (public.can_access_study(study_id));
```

---

## FEEDBACK

### Policy: "attending inserts feedback"
**Purpose:** Allow attendings (or admins) to insert feedback for studies in their institution
```sql
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
```

### Policy: "select feedback if authorized"
**Purpose:** Allow users to select feedback if they can access the parent study
```sql
create policy "select feedback if authorized"
on public.feedback for select
to authenticated
using (public.can_access_study(study_id));
```

---

## SIGNOFFS

### Policy: "attending inserts signoff"
**Purpose:** Allow attendings (or admins) to create signoffs for studies in their institution
```sql
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
```

### Policy: "select signoffs if authorized"
**Purpose:** Allow users to select signoffs if they can access the parent study
```sql
create policy "select signoffs if authorized"
on public.signoffs for select
to authenticated
using (public.can_access_study(study_id));
```

---

## STORAGE.OBJECTS (bucket: pocus-media)

### Policy: "read media objects if authorized"
**Purpose:** Allow users to read (SELECT) storage objects if they can access the associated media's study
```sql
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
```

### Policy: "insert media objects if authorized"
**Purpose:** Allow fellows to upload storage objects for studies they created, or admins for any study
```sql
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
```

### Policy: "delete media objects if authorized"
**Purpose:** Allow users to delete storage objects if they can access the associated media's study
```sql
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
```

---

## Supporting Functions Used in Policies

These functions are referenced by the policies above:

### `public.is_member_of(inst_id uuid)`
Returns true if the current user is an approved member of the institution.

### `public.has_admin_role()`
Returns true if the current user has an approved admin role in any institution (via either the legacy `role` column or the `roles` array).

### `public.has_admin_or_attending(inst_id uuid)`
Utility wrapper that returns true when the current user has either admin or attending rights for the given institution.

### `public.can_access_study(sid uuid)`
Returns true if the current user can access the study (either created it, or is an approved attending/admin in the study's institution).

### `public.uuid_from_path(name text)`
Extracts the study UUID from an object path shaped like `studies/<institution_id>/<study_id>/...` (used in storage policies).

---

## Notes

1. **Role Approval:** All policies respect the `role_approved` flag in memberships. Only approved memberships (where `role_approved = true` or `role_approved IS NULL`) are considered.

2. **Admin Override:** Most policies include `public.has_admin_role()` checks, allowing admins to bypass normal restrictions.

3. **Storage Path Matching:** The storage policies use `m.storage_path = storage.objects.name` to match media records with storage objects.

4. **Public Institution Access:** The institutions table has a public read policy to allow unauthenticated users to see the institution list during onboarding.
