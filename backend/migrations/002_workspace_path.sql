-- Vincular proyectos con carpeta local (repo / stack Docker) para seguimiento IA.
-- Ejecutar: psql $DATABASE_URL -f 002_workspace_path.sql

begin;

alter table public.projects
  add column if not exists workspace_path text not null default '';

commit;
