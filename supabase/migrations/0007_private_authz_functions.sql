create schema if not exists app_private;

create or replace function app_private.current_app_role()
returns app_role
language sql
security definer
set search_path = public
stable
as $$
  select role from profiles where id = auth.uid()
$$;

create or replace function app_private.current_owner_id()
returns uuid
language sql
security definer
set search_path = public
stable
as $$
  select owner_id from profiles where id = auth.uid()
$$;

create or replace function app_private.is_admin_or_manager()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(app_private.current_app_role() in ('admin', 'manager'), false)
$$;

grant usage on schema app_private to authenticated;
grant execute on function app_private.current_app_role() to authenticated;
grant execute on function app_private.current_owner_id() to authenticated;
grant execute on function app_private.is_admin_or_manager() to authenticated;

alter policy "profiles_select_self_or_admin"
on profiles
using (id = auth.uid() or app_private.is_admin_or_manager());

alter policy "profiles_update_self_or_admin"
on profiles
using (id = auth.uid() or app_private.is_admin_or_manager())
with check (id = auth.uid() or app_private.is_admin_or_manager());

alter policy "owners_select_by_role"
on owners
using (app_private.is_admin_or_manager() or id = app_private.current_owner_id());

alter policy "owners_write_admin_manager"
on owners
using (app_private.is_admin_or_manager())
with check (app_private.is_admin_or_manager());

alter policy "buildings_select_by_related_property"
on buildings
using (
  app_private.is_admin_or_manager()
  or exists (
    select 1 from properties
    where properties.building_id = buildings.id
      and properties.owner_id = app_private.current_owner_id()
  )
);

alter policy "buildings_write_admin_manager"
on buildings
using (app_private.is_admin_or_manager())
with check (app_private.is_admin_or_manager());

alter policy "properties_select_by_owner"
on properties
using (app_private.is_admin_or_manager() or owner_id = app_private.current_owner_id());

alter policy "properties_write_by_owner_or_admin"
on properties
using (app_private.is_admin_or_manager() or owner_id = app_private.current_owner_id())
with check (app_private.is_admin_or_manager() or owner_id = app_private.current_owner_id());

alter policy "tenants_select_by_related_lease"
on tenants
using (
  app_private.is_admin_or_manager()
  or exists (
    select 1
    from leases
    join properties on properties.id = leases.property_id
    where leases.tenant_id = tenants.id
      and properties.owner_id = app_private.current_owner_id()
  )
);

alter policy "tenants_write_admin_manager"
on tenants
using (app_private.is_admin_or_manager())
with check (app_private.is_admin_or_manager());

alter policy "leases_select_by_property_owner"
on leases
using (
  app_private.is_admin_or_manager()
  or exists (
    select 1 from properties
    where properties.id = leases.property_id
      and properties.owner_id = app_private.current_owner_id()
  )
);

alter policy "leases_write_admin_manager"
on leases
using (app_private.is_admin_or_manager())
with check (app_private.is_admin_or_manager());

alter policy "rent_invoices_select_by_property_owner"
on rent_invoices
using (
  app_private.is_admin_or_manager()
  or exists (
    select 1
    from leases
    join properties on properties.id = leases.property_id
    where leases.id = rent_invoices.lease_id
      and properties.owner_id = app_private.current_owner_id()
  )
);

alter policy "rent_invoices_write_admin_manager"
on rent_invoices
using (app_private.is_admin_or_manager())
with check (app_private.is_admin_or_manager());

alter policy "payments_select_by_property_owner"
on payments
using (
  app_private.is_admin_or_manager()
  or exists (
    select 1
    from rent_invoices
    join leases on leases.id = rent_invoices.lease_id
    join properties on properties.id = leases.property_id
    where rent_invoices.id = payments.rent_invoice_id
      and properties.owner_id = app_private.current_owner_id()
  )
);

alter policy "payments_write_admin_manager"
on payments
using (app_private.is_admin_or_manager())
with check (app_private.is_admin_or_manager());

alter policy "reminders_select_by_property_owner"
on reminders
using (
  app_private.is_admin_or_manager()
  or exists (
    select 1
    from rent_invoices
    join leases on leases.id = rent_invoices.lease_id
    join properties on properties.id = leases.property_id
    where rent_invoices.id = reminders.rent_invoice_id
      and properties.owner_id = app_private.current_owner_id()
  )
);

alter policy "reminders_write_admin_manager"
on reminders
using (app_private.is_admin_or_manager())
with check (app_private.is_admin_or_manager());
