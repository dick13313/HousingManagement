# HousingManagement Codex Agent Guide

本文件給 Codex / AI agent / 開發者快速理解此專案。使用者主要以繁體中文溝通，回覆、文件補充與使用者可見介面文字請維持繁體中文。

## 專案定位

這是屋主視角的房租管理系統，用來管理：

- 多位屋主
- 多個社區 / 大樓
- 多間房屋
- 租客與租約
- 每月租金帳款、付款、未繳提醒
- 年度租金收入報表，供所得稅申報整理

設計重點是「長輩也能用」：深色系、簡約、少層級、表格清楚、常用操作使用 modal。

## 技術棧

- Nuxt 3 / Vue 3
- TypeScript
- Supabase Auth + PostgreSQL + RLS
- Netlify static deploy
- Package manager: npm

重要指令：

```powershell
.\node_modules\.bin\nuxt.cmd dev
.\node_modules\.bin\nuxt.cmd generate
```

若使用 npm 可用：

```powershell
npm run dev
npm run generate
```

本機環境曾出現 npm PATH 不穩，若 `npm` 找不到，優先使用 `.\node_modules\.bin\nuxt.cmd`。

## 環境變數

本機使用 `.env`，但不得提交。

前端使用：

```env
NUXT_PUBLIC_SUPABASE_URL=
NUXT_PUBLIC_SUPABASE_KEY=
```

`nuxt.config.ts` 也相容舊名稱：

```env
SUPABASE_URL=
SUPABASE_KEY=
```

`.env.example` 可提交；`.env` 永遠不要提交。

## 重要目錄

- `pages/`：Nuxt 頁面
- `components/`：共用 UI
- `composables/`：Supabase client、Auth、資料表 CRUD helpers
- `assets/css/main.css`：全站深色 UI 樣式
- `types/management.ts`：管理表格欄位型別
- `supabase/migrations/`：資料庫 schema / RLS / function migrations
- `supabase/seed.sql`：若存在，可能是真實房客資料，必須維持 `.gitignore`，不得提交
- `docs/`：需求、技術方案與部署文件
- `UIUX/`：早期 UI/UX 設計參考

## 主要頁面

- `/`：首頁儀表板
- `/owners`：屋主管理
- `/buildings`：社區管理
- `/properties`：房屋管理
- `/tenants`：租客管理
- `/leases`：租約管理
- `/rent`：每月收租管理
- `/payments`：付款紀錄
- `/reminders`：提醒紀錄
- `/reports`：年度租金收入報表與 CSV 匯出
- `/accounts`：帳號管理，只有 admin 顯示與可操作
- `/login`：登入 / 註冊

## 資料模型摘要

核心資料表：

- `owners`
- `buildings`
- `properties`
- `tenants`
- `leases`
- `rent_invoices`
- `payments`
- `reminders`
- `profiles`

重要關聯：

- `properties.owner_id -> owners.id`
- `properties.building_id -> buildings.id`
- `leases.property_id -> properties.id`
- `leases.tenant_id -> tenants.id`
- `rent_invoices.lease_id -> leases.id`
- `payments.rent_invoice_id -> rent_invoices.id`
- `profiles.owner_id -> owners.id`

租客可能搬到其他房屋，透過新增 / 結束租約表達，不應直接覆蓋歷史租約。

租金調漲應透過重新簽約或更新租約金額後重新產生帳款處理。

收租週期使用 `leases.payment_cycle_months` 表示，可支援月繳、季繳、半年繳、年繳與自訂月數。收租頁會依選取期間建立缺少的月份帳單，並補入尚未繳清的差額。

## 權限設計

`profiles.role` 使用 `app_role` enum：

- `admin`：管理全部資料與帳號
- `manager`：管理租務資料
- `owner`：只能看自己 `owner_id` 對應屋主資料

註冊後會由 trigger 自動建立 `profiles`，預設：

- `role = 'owner'`
- `owner_id = null`
- `email` 由 `auth.users.email` 同步

帳號開通流程：

1. 使用者註冊
2. Supabase Auth Users 確認 email
3. admin 到 `/accounts` 設定角色與屋主綁定

`/accounts` 依賴 `supabase/migrations/0008_account_management.sql`：

- 新增 `profiles.email`
- 回填既有使用者 email
- 更新註冊 trigger
- 限制只有 `admin` 可以更新 `profiles`

## Supabase MCP

此 workspace 可透過 Supabase MCP 操作遠端專案。若工具未出現，確認 Codex config：

```toml
[mcp_servers.supabase_mcp]
enabled = true
type = "streamable_http"
url = "https://mcp.supabase.com/mcp?project_ref=muvfydiggwlvujonvyoe"
```

做 schema 變更前先用 `list_tables` 檢查現況。DDL 請用 `apply_migration`，不要用 `execute_sql`。

目前 migration 檔案已到：

- `0009_payment_cycle_months.sql`

遠端是否已套用請以 Supabase migration 狀態或實際 schema 為準，不要只依賴本文件。

## 收租與報表邏輯

每月帳款：

- `rent_invoices.invoice_month` 表示月份，通常是該月 1 日
- `amount_due` 應收
- `amount_paid` 已收
- `status` 包含 `unpaid`、`partial`、`paid`、`overdue`

付款紀錄：

- `payments` 新增 / 更新 / 刪除後，trigger 會刷新對應 `rent_invoices.amount_paid` 與狀態

`/rent`：

- 可選月份
- 可建立本月帳單
- 按房屋編號排序
- 「收租」支援月繳、季繳、半年繳、年繳與自訂月數
- 收款時會呼叫 `create_monthly_rent_invoices` 建立缺少帳單，再新增 payment 補齊未繳差額

`/reports`：

- 以年度彙總
- 以 `rent_invoices.amount_paid` 當作實際收入基準
- 顯示每個屋主、每間房屋 1-12 月收入與全年合計
- 提供 CSV 匯出，含屋主年度小計

## UI 規範

- 整體深色系
- 介面要簡約，避免過度複雜
- 常用資料編輯使用 modal，不要把表單拉到頁面底部
- 表格要能篩選，尤其屋主、社區
- 新增頁面時要在 `components/AppShell.vue` 補選單
- 複用現有 CSS class：`panel`、`filter-bar`、`filter-field`、`primary-button`、`secondary-button`、`text-button`、`modal-panel`

## 程式風格

- Vue component 使用 `<script setup lang="ts">`
- 基礎 CRUD 管理頁優先沿用 `components/ManagementPage.vue`
- Supabase client 與登入狀態優先沿用 `useSupabaseClientLite`、`useAuth`、`useSupabaseTable`
- 使用者可見錯誤訊息維持繁體中文
- 新增 route 時同步更新 `components/AppShell.vue` 的桌面與手機導覽
- 送資料到 Supabase 前注意空字串與 `null` 的差異；既有 CRUD helper 會把 `''` normalize 成 `null`

## 部署

部署平台：Netlify Free。

GitHub Actions workflow：

- `.github/workflows/netlify-deploy.yml`
- push 到 `master` 觸發
- 先 `npm install`
- 檢查 GitHub Secrets
- 用 Supabase public env 跑 `npm run generate`
- 用 `netlify deploy --no-build --dir=.output/public` 上傳

`--no-build` 很重要，避免 Netlify CLI 讀 `netlify.toml` 後第二次 build，導致 Supabase env 沒被帶入。

GitHub Secrets：

- `NETLIFY_AUTH_TOKEN`
- `NETLIFY_SITE_ID`
- `SUPABASE_URL`
- `SUPABASE_KEY`

不要提交任何 secret。

## Git 與資料安全

以下不得提交：

- `.env`
- `.logs/`
- `.nuxt/`
- `.output/`
- `dist/`
- `node_modules/`
- `supabase/seed.sql`

`supabase/seed.sql` 包含真實房客 / 地址資料，只能留在本機。

提交前建議檢查：

```powershell
git status --short --ignored
git grep -n "NETLIFY_AUTH_TOKEN=.*[A-Za-z0-9]\|SUPABASE_KEY=.*[A-Za-z0-9]\|NUXT_PUBLIC_SUPABASE_KEY=.*[A-Za-z0-9]" HEAD
```

若要檢查真實資料是否誤入 git，可用已知姓名 / 地址 pattern 搜尋。

## 驗證建議

每次前端或 Nuxt route 變更後跑：

```powershell
$env:NUXT_IGNORE_LOCK='1'; .\node_modules\.bin\nuxt.cmd generate
```

常見可快速檢查 URL：

```powershell
Invoke-WebRequest -Uri http://localhost:3000/accounts -UseBasicParsing
Invoke-WebRequest -Uri http://localhost:3000/reports -UseBasicParsing
```

若 port 3000 已被占用，可用：

```powershell
netstat -ano | Select-String ':3000'
```

不要隨意停止使用者正在用的 dev server，除非使用者要求。

## 接手檢查

接手或修改前請先執行：

```powershell
git status --short --ignored
```

確認工作區是否已有使用者變更。不要覆蓋或 revert 不是自己做的變更。
