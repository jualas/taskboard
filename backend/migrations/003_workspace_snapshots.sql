-- Historial de snapshots de workspace y sugerencias automáticas (Fase 2).
-- Ejecutar: psql $DATABASE_URL -f 003_workspace_snapshots.sql

begin;

create table if not exists public.workspace_snapshots (
  id bigserial primary key,
  project_id integer not null references public.projects(id) on delete cascade,
  snapshot jsonb not null,
  git_commit text,
  git_branch text,
  dirty_count integer not null default 0,
  summary text not null default '',
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_workspace_snapshots_project_created
  on public.workspace_snapshots (project_id, created_at desc);

create table if not exists public.workspace_suggestions (
  id bigserial primary key,
  project_id integer not null references public.projects(id) on delete cascade,
  snapshot_id bigint references public.workspace_snapshots(id) on delete set null,
  suggestion_type text not null
    check (suggestion_type in ('info', 'project_status', 'task')),
  title text not null,
  body text not null default '',
  payload jsonb not null default '{}'::jsonb,
  state text not null default 'pending'
    check (state in ('pending', 'dismissed', 'applied')),
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_workspace_suggestions_project_state
  on public.workspace_suggestions (project_id, state);

create index if not exists idx_workspace_suggestions_pending
  on public.workspace_suggestions (project_id)
  where state = 'pending';

commit;
