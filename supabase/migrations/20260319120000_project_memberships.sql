-- Multiusuario para proyectos TaskBoard.
-- Esta migración implementa:
-- 1) owner_id en projects
-- 2) tabla project_members con roles
-- 3) políticas RLS para projects, project_members y tasks

begin;

alter table public.projects
  add column if not exists owner_id uuid;

-- Backfill: intentamos asignar owner_id al usuario actual si existe;
-- si no (por ejemplo durante migraciones vía service role), asignamos el
-- primer usuario disponible para no romper la migración.
-- Si no hay usuarios, owner_id puede quedar null y esas filas quedarán
-- bloqueadas hasta ser reclamadas mediante una actualización desde la app.
update public.projects
set owner_id = coalesce(
  owner_id,
  auth.uid(),
  (select u.id from auth.users u order by u.created_at asc limit 1)
)
where owner_id is null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'projects_owner_id_fkey'
  ) then
    alter table public.projects
      add constraint projects_owner_id_fkey
      foreign key (owner_id) references auth.users(id) on delete cascade;
  end if;
end $$;

create table if not exists public.project_members (
  project_id integer not null references public.projects(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'viewer' check (role in ('owner', 'editor', 'viewer')),
  invited_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (project_id, user_id)
);

create index if not exists idx_project_members_user_id
  on public.project_members(user_id);

create or replace function public.ensure_project_owner_membership()
returns trigger
language plpgsql
as $$
begin
  -- Si owner_id sigue siendo null, no podemos crear membership.
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

alter table public.projects enable row level security;
alter table public.project_members enable row level security;
alter table public.tasks enable row level security;

create or replace function public.is_project_owner(_project_id integer, _user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.projects p
    where p.id = _project_id
      and p.owner_id = _user_id
  );
$$;

create or replace function public.has_project_membership(_project_id integer, _user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.project_members pm
    where pm.project_id = _project_id
      and pm.user_id = _user_id
  );
$$;

create or replace function public.can_edit_project(_project_id integer, _user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_project_owner(_project_id, _user_id)
    or exists (
      select 1
      from public.project_members pm
      where pm.project_id = _project_id
        and pm.user_id = _user_id
        and pm.role in ('owner', 'editor')
    );
$$;

drop policy if exists projects_select_policy on public.projects;
create policy projects_select_policy
on public.projects
for select
using (
  public.is_project_owner(id, auth.uid())
  or public.has_project_membership(id, auth.uid())
);

drop policy if exists projects_insert_policy on public.projects;
create policy projects_insert_policy
on public.projects
for insert
with check (owner_id = auth.uid());

drop policy if exists projects_update_policy on public.projects;
create policy projects_update_policy
on public.projects
for update
using (public.can_edit_project(id, auth.uid()))
with check (public.can_edit_project(id, auth.uid()));

drop policy if exists projects_delete_policy on public.projects;
create policy projects_delete_policy
on public.projects
for delete
using (public.is_project_owner(id, auth.uid()));

drop policy if exists project_members_select_policy on public.project_members;
create policy project_members_select_policy
on public.project_members
for select
using (
  user_id = auth.uid()
  or public.is_project_owner(project_id, auth.uid())
  or public.has_project_membership(project_id, auth.uid())
);

drop policy if exists project_members_insert_policy on public.project_members;
create policy project_members_insert_policy
on public.project_members
for insert
with check (public.can_edit_project(project_id, auth.uid()));

drop policy if exists project_members_update_policy on public.project_members;
create policy project_members_update_policy
on public.project_members
for update
using (public.can_edit_project(project_id, auth.uid()))
with check (public.can_edit_project(project_id, auth.uid()));

drop policy if exists project_members_delete_policy on public.project_members;
create policy project_members_delete_policy
on public.project_members
for delete
using (public.can_edit_project(project_id, auth.uid()));

drop policy if exists tasks_select_policy on public.tasks;
create policy tasks_select_policy
on public.tasks
for select
using (
  public.is_project_owner(project_id, auth.uid())
  or public.has_project_membership(project_id, auth.uid())
);

drop policy if exists tasks_insert_policy on public.tasks;
create policy tasks_insert_policy
on public.tasks
for insert
with check (public.can_edit_project(project_id, auth.uid()));

drop policy if exists tasks_update_policy on public.tasks;
create policy tasks_update_policy
on public.tasks
for update
using (public.can_edit_project(project_id, auth.uid()))
with check (public.can_edit_project(project_id, auth.uid()));

drop policy if exists tasks_delete_policy on public.tasks;
create policy tasks_delete_policy
on public.tasks
for delete
using (public.can_edit_project(project_id, auth.uid()));

commit;
