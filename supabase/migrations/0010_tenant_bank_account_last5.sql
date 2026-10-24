alter table public.tenants
  add column bank_account_last5 text;

alter table public.tenants
  add constraint tenants_bank_account_last5_format
  check (bank_account_last5 is null or bank_account_last5 ~ '^[0-9]{5}$');

comment on column public.tenants.bank_account_last5 is
  'Last five digits of the tenant bank account, used to identify incoming rent transfers.';

create index tenants_bank_account_last5_idx
  on public.tenants (bank_account_last5)
  where bank_account_last5 is not null;
