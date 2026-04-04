-- Corrige creación de proyectos con RLS:
-- 1) owner_id nulo en INSERT (política: owner_id = auth.uid())
-- 2) IDs duplicados: getNextProjectId() solo ve filas permitidas por SELECT RLS

begin;

-- Asegura owner_id antes del INSERT si el cliente no lo envía
create or replace function public.projects_before_insert_set_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.owner_id is null then
    new.owner_id := auth.uid();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_projects_before_insert_set_owner on public.projects;
create trigger trg_projects_before_insert_set_owner
before insert on public.projects
for each row execute function public.projects_before_insert_set_owner();

-- Siguiente id global (evita colisión cuando el usuario no ve otros proyectos)
create or replace function public.next_project_id()
returns integer
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(max(id), 0) + 1 from public.projects;
$$;

grant execute on function public.next_project_id() to authenticated;
grant execute on function public.next_project_id() to service_role;

commit;
