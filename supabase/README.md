# Supabase

此目錄保存 Supabase 資料庫 migration。

## 初始資料表

`migrations/0001_initial_schema.sql` 建立以下核心資料：

- owners
- buildings
- properties
- tenants
- leases
- rent_invoices
- payments
- reminders

`migrations/0002_payment_rollup.sql` 會在新增、修改、刪除付款紀錄後，自動更新租金帳款的已繳金額與狀態。

`migrations/0003_monthly_invoice_and_reminders.sql` 提供每月產生帳款與建立逾期提醒的資料庫 function。

`migrations/0004_rls_and_function_security.sql` 啟用 RLS、固定 function search_path，並允許已登入使用者讀寫。

`migrations/0005_auth_profile_trigger.sql` 會在使用者註冊時自動建立 owner profile。管理者角色需由已授權人員明確指定。

## 後續規劃

接下來應補上：

- Auth 使用者與屋主或管理者角色關聯
- Row Level Security policies
- 每月帳款產生 function
- 未繳租金每日檢查 function
- 提醒紀錄產生 function

## 建議 Supabase Cron

每日產生逾期提醒：

```sql
select create_overdue_in_app_reminders();
```

每月產生租金帳款：

```sql
select create_monthly_rent_invoices(date_trunc('month', current_date)::date);
```
