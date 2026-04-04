begin;

create or replace function public.list_registered_users()
returns table(user_id uuid, email text)
language sql
stable
security definer
set search_path = public, auth
as $$
  select u.id as user_id, u.email
  from auth.users u
  where u.email is not null
  order by lower(u.email);
$$;

revoke all on function public.list_registered_users() from public;
grant execute on function public.list_registered_users() to authenticated;

commit;
