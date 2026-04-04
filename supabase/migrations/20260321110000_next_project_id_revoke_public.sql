-- Evita que el rol PUBLIC ejecute next_project_id() sin ser usuario autenticado.
-- Sin esto, una petición con solo la anon key podía obtener un id mientras el INSERT en projects fallaba por RLS.
-- Debe aplicarse después de 20260321100000_projects_rls_insert_fix.sql (define la función).

begin;

revoke all on function public.next_project_id() from public;

grant execute on function public.next_project_id() to authenticated;
grant execute on function public.next_project_id() to service_role;

commit;
