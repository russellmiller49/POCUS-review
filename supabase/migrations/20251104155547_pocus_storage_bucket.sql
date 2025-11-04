-- Private bucket for POCUS media
-- (idempotent: will no-op if bucket already exists)
insert into storage.buckets (id, name, public)
select 'pocus-media', 'pocus-media', false
where not exists (select 1 from storage.buckets where id = 'pocus-media');

