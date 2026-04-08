-- Relax the studies insert policy so any authenticated member of an institution
-- can create a study. The previous policy required `public.has_role(..., 'fellow')`,
-- but during onboarding the role data can live either in the legacy `role` column
-- or the new `roles` array, which caused legitimate fellows to fail the check.
-- We already gate the creation UI in the app, so the database can simply verify
-- membership + ownership to unblock uploads.

drop policy if exists "fellow inserts own studies" on public.studies;

create policy "member inserts own studies"
on public.studies
for insert
to authenticated
with check (
  created_by = auth.uid()
  and public.is_member_of(institution_id)
);
