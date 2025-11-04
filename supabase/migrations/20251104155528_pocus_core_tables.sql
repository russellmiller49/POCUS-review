-- Extensions
create extension if not exists pgcrypto; -- for gen_random_uuid()

-- 1) Institutions (multi-tenant support)
create table if not exists public.institutions (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.institutions enable row level security;

-- 2) Memberships (user roles per institution)
create table if not exists public.memberships (
  user_id uuid not null references auth.users(id) on delete cascade,
  institution_id uuid not null references public.institutions(id) on delete cascade,
  role text not null check (role in ('fellow', 'attending', 'admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, institution_id)
);
alter table public.memberships enable row level security;

-- 3) Studies (fellow submissions)
create table if not exists public.studies (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  exam_type text not null,
  status text not null default 'draft' check (status in ('draft', 'submitted', 'reviewable', 'needs_revision', 'approved', 'signed_off')),
  submitted_at timestamptz,
  notes text,
  assigned_attending uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.studies enable row level security;

-- 4) Media (images/videos associated with studies)
create table if not exists public.media (
  id uuid primary key default gen_random_uuid(),
  study_id uuid not null references public.studies(id) on delete cascade,
  kind text not null check (kind in ('image', 'video', 'clip', 'other')),
  storage_path text not null,
  content_type text not null,
  duration_sec numeric,
  width integer,
  height integer,
  sha256 text,
  status text not null default 'pending' check (status in ('pending', 'uploading', 'clean', 'failed')),
  created_at timestamptz not null default now()
);
alter table public.media enable row level security;

-- 5) Feedback (attending reviews)
create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),
  study_id uuid not null references public.studies(id) on delete cascade,
  reviewer_id uuid not null references auth.users(id) on delete restrict,
  rating integer check (rating between 1 and 5),
  comments text,
  created_at timestamptz not null default now()
);
alter table public.feedback enable row level security;

-- 6) Signoffs (attending signoff status)
create table if not exists public.signoffs (
  id uuid primary key default gen_random_uuid(),
  study_id uuid not null references public.studies(id) on delete cascade,
  attending_id uuid not null references auth.users(id) on delete restrict,
  status text not null check (status in ('pending', 'approved', 'revisions')),
  signed_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.signoffs enable row level security;

