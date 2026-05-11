create or replace function refresh_invoice_payment_status(target_invoice_id uuid)
returns void
language plpgsql
as $$
declare
  paid_total integer;
  due_total integer;
  due_date date;
begin
  select coalesce(sum(amount), 0)
  into paid_total
  from payments
  where rent_invoice_id = target_invoice_id;

  select amount_due, due_on
  into due_total, due_date
  from rent_invoices
  where id = target_invoice_id;

  update rent_invoices
  set
    amount_paid = paid_total,
    status = case
      when paid_total >= due_total then 'paid'::invoice_status
      when paid_total > 0 then 'partial'::invoice_status
      when due_date < current_date then 'overdue'::invoice_status
      else 'unpaid'::invoice_status
    end
  where id = target_invoice_id;
end;
$$;

create or replace function payments_refresh_invoice()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    perform refresh_invoice_payment_status(old.rent_invoice_id);
    return old;
  end if;

  perform refresh_invoice_payment_status(new.rent_invoice_id);

  if tg_op = 'UPDATE' and old.rent_invoice_id <> new.rent_invoice_id then
    perform refresh_invoice_payment_status(old.rent_invoice_id);
  end if;

  return new;
end;
$$;

create trigger payments_refresh_invoice_after_insert
after insert on payments
for each row execute function payments_refresh_invoice();

create trigger payments_refresh_invoice_after_update
after update on payments
for each row execute function payments_refresh_invoice();

create trigger payments_refresh_invoice_after_delete
after delete on payments
for each row execute function payments_refresh_invoice();
