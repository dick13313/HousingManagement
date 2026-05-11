create or replace function handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into profiles (id, role, display_name)
  values (
    new.id,
    'owner'::app_role,
    coalesce(new.raw_user_meta_data ->> 'display_name', new.email)
  );

  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function handle_new_user_profile();
