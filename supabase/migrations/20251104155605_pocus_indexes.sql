-- Performance indexes on foreign keys and commonly queried columns

-- Institutions
create index if not exists idx_institutions_slug on public.institutions (slug);

-- Memberships
create index if not exists idx_memberships_user_id on public.memberships (user_id);
create index if not exists idx_memberships_institution_id on public.memberships (institution_id);
create index if not exists idx_memberships_role on public.memberships (institution_id, role);

-- Studies
create index if not exists idx_studies_institution_id on public.studies (institution_id);
create index if not exists idx_studies_created_by on public.studies (created_by);
create index if not exists idx_studies_status on public.studies (status);
create index if not exists idx_studies_created_at on public.studies (created_at desc);

-- Media
create index if not exists idx_media_study_id on public.media (study_id);
create index if not exists idx_media_status on public.media (status);

-- Feedback
create index if not exists idx_feedback_study_id on public.feedback (study_id);
create index if not exists idx_feedback_reviewer_id on public.feedback (reviewer_id);

-- Signoffs
create index if not exists idx_signoffs_study_id on public.signoffs (study_id);
create index if not exists idx_signoffs_attending_id on public.signoffs (attending_id);
create index if not exists idx_signoffs_status on public.signoffs (status);

