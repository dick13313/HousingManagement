create or replace function create_monthly_rent_invoices(target_month date default date_trunc('month', current_date)::date)
returns integer
language plpgsql
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

create or replace function create_overdue_in_app_reminders()
returns integer
language plpgsql
as $$
declare
  inserted_count integer;
begin
  insert into reminders (rent_invoice_id, tenant_id, channel, status, notes)
  select
    rent_invoices.id,
    leases.tenant_id,
    'in_app'::reminder_channel,
    'pending'::reminder_status,
    '系統自動建立的逾期提醒'
  from rent_invoices
  join leases on leases.id = rent_invoices.lease_id
  where rent_invoices.status in ('unpaid', 'partial', 'overdue')
    and rent_invoices.due_on < current_date
    and not exists (
      select 1
      from reminders
      where reminders.rent_invoice_id = rent_invoices.id
        and reminders.created_at::date = current_date
    );

  get diagnostics inserted_count = row_count;
  return inserted_count;
end;
$$;
