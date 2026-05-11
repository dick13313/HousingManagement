revoke execute on function current_app_role() from anon, authenticated;
revoke execute on function current_owner_id() from anon, authenticated;
revoke execute on function is_admin_or_manager() from anon, authenticated;
revoke execute on function handle_new_user_profile() from anon, authenticated;
revoke execute on function current_app_role() from public;
revoke execute on function current_owner_id() from public;
revoke execute on function is_admin_or_manager() from public;
revoke execute on function handle_new_user_profile() from public;
