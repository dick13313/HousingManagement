create extension if not exists "pgcrypto";

create type property_status as enum ('vacant', 'rented', 'disabled');
create type lease_status as enum ('active', 'ending_soon', 'ended');
create type invoice_status as enum ('unpaid', 'partial', 'paid', 'overdue');
create type payment_method as enum ('cash', 'bank_transfer', 'check', 'other');
create type reminder_status as enum ('pending', 'sent', 'failed');
create type reminder_channel as enum ('in_app', 'email', 'line', 'sms');

create table owners (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  email text,
  address text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table buildings (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text,
  manager_name text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table properties (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references owners(id),
  building_id uuid references buildings(id),
  address text not null,
  floor text,
  unit_no text,
  layout text,
  area_ping numeric(8, 2),
  status property_status not null default 'vacant',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  email text,
  line_id text,
  identity_no text,
  emergency_contact text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table leases (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  property_id uuid not null references properties(id),
  starts_on date not null,
  ends_on date not null,
  monthly_rent integer not null check (monthly_rent >= 0),
  deposit integer not null default 0 check (deposit >= 0),
  rent_due_day integer not null check (rent_due_day between 1 and 31),
  status lease_status not null default 'active',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_on >= starts_on)
);

create table rent_invoices (
  id uuid primary key default gen_random_uuid(),
  lease_id uuid not null references leases(id),
  invoice_month date not null,
  amount_due integer not null check (amount_due >= 0),
  amount_paid integer not null default 0 check (amount_paid >= 0),
  due_on date not null,
  status invoice_status not null default 'unpaid',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (lease_id, invoice_month),
  check (amount_paid <= amount_due)
);

create table payments (
  id uuid primary key default gen_random_uuid(),
  rent_invoice_id uuid not null references rent_invoices(id),
  paid_on date not null,
  amount integer not null check (amount > 0),
  method payment_method not null default 'bank_transfer',
  receipt_no text,
  notes text,
  created_at timestamptz not null default now()
);

create table reminders (
  id uuid primary key default gen_random_uuid(),
  rent_invoice_id uuid not null references rent_invoices(id),
  tenant_id uuid not null references tenants(id),
  channel reminder_channel not null default 'in_app',
  status reminder_status not null default 'pending',
  sent_at timestamptz,
  failed_reason text,
  notes text,
  created_at timestamptz not null default now()
);

create index properties_owner_id_idx on properties(owner_id);
create index properties_building_id_idx on properties(building_id);
create index leases_tenant_id_idx on leases(tenant_id);
create index leases_property_id_idx on leases(property_id);
create index rent_invoices_lease_id_idx on rent_invoices(lease_id);
create index rent_invoices_status_due_on_idx on rent_invoices(status, due_on);
create index payments_rent_invoice_id_idx on payments(rent_invoice_id);
create index reminders_rent_invoice_id_idx on reminders(rent_invoice_id);
create index reminders_tenant_id_idx on reminders(tenant_id);

create or replace function update_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger owners_updated_at
before update on owners
for each row execute function update_updated_at();

create trigger buildings_updated_at
before update on buildings
for each row execute function update_updated_at();

create trigger properties_updated_at
before update on properties
for each row execute function update_updated_at();

create trigger tenants_updated_at
before update on tenants
for each row execute function update_updated_at();

create trigger leases_updated_at
before update on leases
for each row execute function update_updated_at();

create trigger rent_invoices_updated_at
before update on rent_invoices
for each row execute function update_updated_at();
