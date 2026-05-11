create type app_role as enum ('admin', 'manager', 'owner');

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  owner_id uuid references owners(id),
  role app_role not null default 'owner',
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter function update_updated_at() set search_path = public;
alter function refresh_invoice_payment_status(uuid) set search_path = public;
alter function payments_refresh_invoice() set search_path = public;
alter function create_monthly_rent_invoices(date) set search_path = public;
alter function create_overdue_in_app_reminders() set search_path = public;

create or replace function current_app_role()
returns app_role
language sql
security definer
set search_path = public
stable
as $$
  select role from profiles where id = auth.uid()
$$;

create or replace function current_owner_id()
returns uuid
language sql
security definer
set search_path = public
stable
as $$
  select owner_id from profiles where id = auth.uid()
$$;

create or replace function is_admin_or_manager()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(current_app_role() in ('admin', 'manager'), false)
$$;

create trigger profiles_updated_at
before update on profiles
for each row execute function update_updated_at();

alter table profiles enable row level security;
alter table owners enable row level security;
alter table buildings enable row level security;
alter table properties enable row level security;
alter table tenants enable row level security;
alter table leases enable row level security;
alter table rent_invoices enable row level security;
alter table payments enable row level security;
alter table reminders enable row level security;

create policy "profiles_select_self_or_admin"
on profiles for select
to authenticated
using (id = auth.uid() or is_admin_or_manager());

create policy "profiles_update_self_or_admin"
on profiles for update
to authenticated
using (id = auth.uid() or is_admin_or_manager())
with check (id = auth.uid() or is_admin_or_manager());

create policy "owners_select_by_role"
on owners for select
to authenticated
using (is_admin_or_manager() or id = current_owner_id());

create policy "owners_write_admin_manager"
on owners for all
to authenticated
using (is_admin_or_manager())
with check (is_admin_or_manager());

create policy "buildings_select_by_related_property"
on buildings for select
to authenticated
using (
  is_admin_or_manager()
  or exists (
    select 1 from properties
    where properties.building_id = buildings.id
      and properties.owner_id = current_owner_id()
  )
);

create policy "buildings_write_admin_manager"
on buildings for all
to authenticated
using (is_admin_or_manager())
with check (is_admin_or_manager());

create policy "properties_select_by_owner"
on properties for select
to authenticated
using (is_admin_or_manager() or owner_id = current_owner_id());

create policy "properties_write_by_owner_or_admin"
on properties for all
to authenticated
using (is_admin_or_manager() or owner_id = current_owner_id())
with check (is_admin_or_manager() or owner_id = current_owner_id());

create policy "tenants_select_by_related_lease"
on tenants for select
to authenticated
using (
  is_admin_or_manager()
  or exists (
    select 1
    from leases
    join properties on properties.id = leases.property_id
    where leases.tenant_id = tenants.id
      and properties.owner_id = current_owner_id()
  )
);

create policy "tenants_write_admin_manager"
on tenants for all
to authenticated
using (is_admin_or_manager())
with check (is_admin_or_manager());

create policy "leases_select_by_property_owner"
on leases for select
to authenticated
using (
  is_admin_or_manager()
  or exists (
    select 1 from properties
    where properties.id = leases.property_id
      and properties.owner_id = current_owner_id()
  )
);

create policy "leases_write_admin_manager"
on leases for all
to authenticated
using (is_admin_or_manager())
with check (is_admin_or_manager());

create policy "rent_invoices_select_by_property_owner"
on rent_invoices for select
to authenticated
using (
  is_admin_or_manager()
  or exists (
    select 1
    from leases
    join properties on properties.id = leases.property_id
    where leases.id = rent_invoices.lease_id
      and properties.owner_id = current_owner_id()
  )
);

create policy "rent_invoices_write_admin_manager"
on rent_invoices for all
to authenticated
using (is_admin_or_manager())
with check (is_admin_or_manager());

create policy "payments_select_by_property_owner"
on payments for select
to authenticated
using (
  is_admin_or_manager()
  or exists (
    select 1
    from rent_invoices
    join leases on leases.id = rent_invoices.lease_id
    join properties on properties.id = leases.property_id
    where rent_invoices.id = payments.rent_invoice_id
      and properties.owner_id = current_owner_id()
  )
);

create policy "payments_write_admin_manager"
on payments for all
to authenticated
using (is_admin_or_manager())
with check (is_admin_or_manager());

create policy "reminders_select_by_property_owner"
on reminders for select
to authenticated
using (
  is_admin_or_manager()
  or exists (
    select 1
    from rent_invoices
    join leases on leases.id = rent_invoices.lease_id
    join properties on properties.id = leases.property_id
    where rent_invoices.id = reminders.rent_invoice_id
      and properties.owner_id = current_owner_id()
  )
);

create policy "reminders_write_admin_manager"
on reminders for all
to authenticated
using (is_admin_or_manager())
with check (is_admin_or_manager());
