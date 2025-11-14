-- Ensure each study can only have one signoff record so that upsert works reliably.

alter table public.signoffs
    drop constraint if exists signoffs_study_id_key;

alter table public.signoffs
    add constraint signoffs_study_id_key unique (study_id);
