# Copilot Instructions for HousingManagement

請以繁體中文回覆與撰寫使用者可見文字。本專案是屋主視角的房租管理系統，重點是協助管理多位屋主、多個社區 / 大樓、多間房屋、租客、租約、每月租金帳款、付款、提醒與年度租金收入報表。

## 技術棧與執行

- 使用 Nuxt 3、Vue 3、TypeScript。
- 後端資料與登入使用 Supabase Auth、PostgreSQL、RLS。
- 部署目標是 Netlify static deploy。
- 套件管理使用 npm。
- 常用指令：
  - `npm run dev`
  - `npm run generate`
  - 若 Windows PATH 或 npm 不穩，優先使用 `.\node_modules\.bin\nuxt.cmd dev` 或 `.\node_modules\.bin\nuxt.cmd generate`。

## 專案結構

- `pages/`：Nuxt route pages。
- `components/`：共用 UI，例如 `AppShell.vue`、`ManagementPage.vue`、`StatusPill.vue`。
- `composables/`：Supabase client、Auth、CRUD helper、參考選項。
- `assets/css/main.css`：全站深色 UI 樣式。
- `types/management.ts`：管理頁欄位與表格型別。
- `supabase/migrations/`：資料庫 schema、RLS、function migration。
- `docs/`：專案目標、技術方案、部署文件。
- `UIUX/`：早期 UI/UX 參考。

## 產品與資料模型原則

- 租客不要直接綁定在房屋資料上；租客與房屋透過 `leases` 表示，以保留搬家、退租與重新承租歷史。
- 租金不要直接綁定在房屋資料上；租金條件放在 `leases.monthly_rent`，調租應透過續約、重新簽約或明確的租約異動。
- 每月租金帳款使用 `rent_invoices` 獨立紀錄，`invoice_month` 通常是該月 1 日。
- 付款紀錄使用 `payments`，付款異動會由資料庫 trigger 更新 `rent_invoices.amount_paid` 與 `status`。
- 收租頁支援月繳、季繳、半年繳、年繳與自訂月數，租約週期欄位為 `leases.payment_cycle_months`。

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

## 權限與登入

- 使用 Supabase Auth。
- `profiles.role` 使用 `app_role` enum：
  - `admin`：管理全部資料與帳號。
  - `manager`：管理租務資料。
  - `owner`：只能看自己 `owner_id` 對應屋主資料。
- 註冊後 trigger 會建立 `profiles`，預設 `role = 'owner'` 且 `owner_id = null`。
- `/accounts` 只應讓 admin 看見與操作；新增管理功能時要留意 RLS 與 UI 雙層限制。

## UI 與互動慣例

- 使用深色、簡約、表格清楚的管理系統風格，目標是「長輩也能用」。
- 常用新增 / 編輯動作使用 modal，不要把大型表單堆在頁面底部。
- 表格應支援實用篩選，尤其屋主、社區 / 大樓。
- 新增頁面時同步更新 `components/AppShell.vue` 導覽。
- 優先複用既有 CSS class：`panel`、`filter-bar`、`filter-field`、`primary-button`、`secondary-button`、`text-button`、`modal-panel`。
- 使用者可見文字維持繁體中文，語氣直接清楚。

## Nuxt / Vue 寫法慣例

- 使用 `<script setup lang="ts">`。
- 優先沿用既有 composables，而不是在頁面中重複 Supabase 初始化。
- 基礎 CRUD 管理頁優先考慮 `components/ManagementPage.vue`。
- 空字串要送到資料庫時，注意既有 helper 會將 `''` normalize 成 `null`。
- 金額、月份、房號排序等格式化邏輯應維持一致，房號排序使用 zh-TW locale 並開啟 numeric。

## Supabase migration 規則

- schema 變更要新增 `supabase/migrations/NNNN_description.sql`，不要直接改舊 migration。
- function 請設定 `set search_path = public`。
- DDL 與 RLS 變更需考慮 `admin`、`manager`、`owner` 三種角色。
- 不要提交真實 seed 或租客個資；`supabase/seed.sql` 若存在是本機真實資料，必須留在 gitignore。

## 環境變數與安全

- `.env` 不得提交。
- 前端 runtime config 支援：
  - `NUXT_PUBLIC_SUPABASE_URL`
  - `NUXT_PUBLIC_SUPABASE_KEY`
  - 舊名稱 `SUPABASE_URL`
  - 舊名稱 `SUPABASE_KEY`
- 不要在程式、文件、測試輸出中硬編碼 Supabase key、Netlify token 或任何個資。

## 驗證

- 前端或 route 變更後至少執行：
  - `npm run generate`
  - 或 Windows fallback：`$env:NUXT_IGNORE_LOCK='1'; .\node_modules\.bin\nuxt.cmd generate`
- 若變更 UI，需手動檢查相關頁面是否能載入、modal 是否可開關、表格與篩選不破版。
- 部署流程在 `.github/workflows/netlify-deploy.yml`，push 到 `master` 時會產生 static output 並部署到 Netlify。
