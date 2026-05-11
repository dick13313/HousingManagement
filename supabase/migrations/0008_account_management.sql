alter table profiles
add column if not exists email text;

update profiles
set email = auth_users.email
from auth.users auth_users
where profiles.id = auth_users.id
  and profiles.email is distinct from auth_users.email;

create index if not exists profiles_email_idx on profiles(email);

create or replace function handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into profiles (id, role, display_name, email)
  values (
    new.id,
    'owner'::app_role,
    coalesce(new.raw_user_meta_data ->> 'display_name', new.email),
    new.email
  );

  return new;
end;
$$;

drop policy if exists "profiles_update_self_or_admin" on profiles;

create policy "profiles_update_admin"
on profiles for update
to authenticated
using (app_private.current_app_role() = 'admin')
with check (app_private.current_app_role() = 'admin');
