alter table leases
add column if not exists payment_cycle_months integer not null default 1
check (payment_cycle_months between 1 and 36);

comment on column leases.payment_cycle_months is 'Default number of rent months collected at once for this lease.';

create or replace function create_monthly_rent_invoices(target_month date default date_trunc('month', current_date)::date)
returns integer
language plpgsql
set search_path = public
as $$
declare
  inserted_count integer;
begin
  insert into rent_invoices (lease_id, invoice_month, amount_due, due_on, status)
  select
    leases.id,
    date_trunc('month', target_month)::date,
    leases.monthly_rent,
    (
      date_trunc('month', target_month)::date
      + ((least(leases.rent_due_day, 28) - 1) || ' days')::interval
    )::date,
    'unpaid'::invoice_status
  from leases
  where leases.status = 'active'
    and leases.starts_on <= (date_trunc('month', target_month) + interval '1 month - 1 day')::date
    and leases.ends_on >= date_trunc('month', target_month)::date
  on conflict (lease_id, invoice_month) do nothing;

  get diagnostics inserted_count = row_count;
  return inserted_count;
end;
$$;
