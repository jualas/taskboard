-- Creación de proyectos vía RPC: el INSERT lo ejecuta el dueño de la función (bypass RLS),
-- pero owner_id solo puede ser auth.uid() leído del JWT de la petición (igual que otras RPC security definer).

begin;

create or replace function public.create_project(
  p_title text,
  p_description text default '',
  p_status text default 'planning'
)
returns public.projects
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  nid integer;
  r public.projects%rowtype;
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select public.next_project_id() into nid;

  insert into public.projects (
    id,
    title,
    description,
    status,
    owner_id,
    created_at,
    updated_at
  )
  values (
    nid,
    coalesce(nullif(trim(p_title), ''), 'Sin título'),
    coalesce(p_description, ''),
    case
      when p_status in ('planning', 'development', 'completed', 'archived') then p_status
      else 'planning'
    end,
    uid,
    timezone('utc', now()),
    timezone('utc', now())
  )
  returning * into r;

  return r;
end;
$$;

revoke all on function public.create_project(text, text, text) from public;
grant execute on function public.create_project(text, text, text) to authenticated;
grant execute on function public.create_project(text, text, text) to service_role;

commit;
