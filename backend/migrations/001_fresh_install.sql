-- Instalación limpia: Postgres + TaskBoard API (sin Supabase).
-- Ejecutar: psql $DATABASE_URL -f 001_fresh_install.sql

begin;

create extension if not exists pgcrypto;

create table if not exists public.app_users (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  password_hash text not null,
  display_name text,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.projects (
  id integer primary key,
  title text not null default '',
  description text not null default '',
  status text not null default 'planning'
    check (status in ('planning', 'development', 'completed', 'archived')),
  owner_id uuid not null references public.app_users(id) on delete cascade,
  created_at timestamptz not null,
  updated_at timestamptz not null
);

create table if not exists public.project_members (
  project_id integer not null references public.projects(id) on delete cascade,
  user_id uuid not null references public.app_users(id) on delete cascade,
  role text not null default 'viewer' check (role in ('owner', 'editor', 'viewer')),
  invited_by uuid references public.app_users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (project_id, user_id)
);

create index if not exists idx_project_members_user_id on public.project_members(user_id);

create table if not exists public.tasks (
  id integer primary key,
  project_id integer not null references public.projects(id) on delete cascade,
  title text not null default '',
  description text not null default '',
  status text not null default 'pending',
  due_date timestamptz,
  kanban_position double precision not null default 1,
  estimated_hours integer,
  complexity text not null default 'simple',
  tags jsonb not null default '[]'::jsonb,
  subtasks jsonb not null default '[]'::jsonb,
  created_at timestamptz not null,
  updated_at timestamptz not null
);

create or replace function public.ensure_project_owner_membership()
returns trigger
language plpgsql
as $$
begin
  if new.owner_id is null then
    return new;
  end if;
  insert into public.project_members(project_id, user_id, role, invited_by)
  values (new.id, new.owner_id, 'owner', new.owner_id)
  on conflict (project_id, user_id) do update set role = 'owner';
  return new;
end;
$$;

drop trigger if exists trg_ensure_project_owner_membership on public.projects;
create trigger trg_ensure_project_owner_membership
after insert or update of owner_id on public.projects
for each row execute function public.ensure_project_owner_membership();

-- Sin RLS: el API FastAPI aplica permisos.

commit;
