-- Sesiones Cursor Agent e historial de ejecuciones por proyecto (Fase Agent UI).
-- Ejecutar: psql $DATABASE_URL -f 004_agent_sessions.sql

begin;

create table if not exists public.project_agent_sessions (
  project_id integer primary key references public.projects(id) on delete cascade,
  session_id text not null,
  workspace_path text not null default '',
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.project_agent_runs (
  id bigserial primary key,
  project_id integer not null references public.projects(id) on delete cascade,
  session_id text,
  prompt text not null,
  execute_mode boolean not null default false,
  result_preview text not null default '',
  is_error boolean not null default false,
  created_by uuid references public.app_users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_project_agent_runs_project_created
  on public.project_agent_runs (project_id, created_at desc);

commit;
