-- Optional API convenience view for fetching study with nested media and feedback
create schema if not exists api;

create or replace view api.study_detail as
select
  s.*,
  (
    select coalesce(json_agg(
      json_build_object(
        'id', m.id,
        'kind', m.kind,
        'storage_path', m.storage_path,
        'content_type', m.content_type,
        'duration_sec', m.duration_sec,
        'width', m.width,
        'height', m.height,
        'status', m.status,
        'created_at', m.created_at
      ) order by m.created_at
    ) filter (where true), '[]'::json)
    from public.media m
    where m.study_id = s.id
  ) as media,
  (
    select coalesce(json_agg(
      json_build_object(
        'id', f.id,
        'reviewer_id', f.reviewer_id,
        'rating', f.rating,
        'comments', f.comments,
        'created_at', f.created_at
      ) order by f.created_at
    ) filter (where true), '[]'::json)
    from public.feedback f
    where f.study_id = s.id
  ) as feedback,
  (
    select coalesce(json_agg(
      json_build_object(
        'id', so.id,
        'attending_id', so.attending_id,
        'status', so.status,
        'signed_at', so.signed_at
      ) order by so.id
    ) filter (where true), '[]'::json)
    from public.signoffs so
    where so.study_id = s.id
  ) as signoffs
from public.studies s;

grant usage on schema api to authenticated;
grant select on api.study_detail to authenticated;

-- RLS on the view (inherits from underlying tables)
alter view api.study_detail set (security_invoker = true);

