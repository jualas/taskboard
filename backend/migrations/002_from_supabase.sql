-- Migración desde instancia Supabase self-hosted hacia esquema app_users + sin RLS.
-- Ejecutar en una copia de seguridad / ventana de mantenimiento.
-- Revisar y adaptar nombres de esquema si difieren.

begin;

create extension if not exists pgcrypto;

-- 1) Tabla de usuarios propia
create table if not exists public.app_users (
  id uuid primary key,
  email text not null unique,
  password_hash text not null,
  display_name text,
  created_at timestamptz not null default timezone('utc', now())
);

-- Usuarios desde auth.users: contraseña temporal hasta que definan una nueva vía /auth/register
-- o script de administración (los hashes de Supabase no son portables a bcrypt del API).
insert into public.app_users (id, email, password_hash)
select u.id, u.email, '$2b$12$placeholderInvalidHashReplaceWithBcrypt'
from auth.users u
where u.email is not null
  and not exists (select 1 from public.app_users a where a.id = u.id)
on conflict (id) do nothing;

-- 2) Soltar FKs hacia auth.users
alter table public.projects drop constraint if exists projects_owner_id_fkey;
alter table public.project_members drop constraint if exists project_members_user_id_fkey;
alter table public.project_members drop constraint if exists project_members_invited_by_fkey;

alter table public.projects
  add constraint projects_owner_id_fkey
  foreign key (owner_id) references public.app_users(id) on delete cascade;

alter table public.project_members
  add constraint project_members_user_id_fkey
  foreign key (user_id) references public.app_users(id) on delete cascade;

alter table public.project_members
  add constraint project_members_invited_by_fkey
  foreign key (invited_by) references public.app_users(id) on delete set null;

-- 3) Desactivar RLS (el API aplica permisos)
alter table if exists public.projects disable row level security;
alter table if exists public.project_members disable row level security;
alter table if exists public.tasks disable row level security;

drop policy if exists projects_select_policy on public.projects;
drop policy if exists projects_insert_policy on public.projects;
drop policy if exists projects_update_policy on public.projects;
drop policy if exists projects_delete_policy on public.projects;
drop policy if exists project_members_select_policy on public.project_members;
drop policy if exists project_members_insert_policy on public.project_members;
drop policy if exists project_members_update_policy on public.project_members;
drop policy if exists project_members_delete_policy on public.project_members;
drop policy if exists tasks_select_policy on public.tasks;
drop policy if exists tasks_insert_policy on public.tasks;
drop policy if exists tasks_update_policy on public.tasks;
drop policy if exists tasks_delete_policy on public.tasks;

-- Actualizar hashes: usar backend/scripts/set_password.py o endpoint admin.

commit;
