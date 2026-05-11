# 房租管理系統技術解決方案

## 選定方案

本專案選定以下技術組合：

- 前端與全端框架：Nuxt 3
- 資料庫與後端服務：Supabase
- 部署平台：Netlify Free
- 備選部署平台：Vercel Hobby

## 選擇理由

### Nuxt 3

Nuxt 3 適合建立管理系統，支援 Vue 生態系、檔案式路由、Server API、SSR、SPA 與靜態部署等模式。

本專案初期可用 Nuxt 3 建立前端管理介面，並透過 Supabase SDK 串接資料庫與登入功能。

### Supabase

Supabase 提供 PostgreSQL、Auth、Row Level Security、Edge Functions、Storage 與 Cron 排程能力。

本系統需要管理屋主、房屋、租客、租約、租金帳款、付款紀錄與提醒紀錄，Supabase 的 PostgreSQL 很適合處理這類關聯式資料。

Supabase Free 方案對初版開發可行：

- 可建立免費專案
- PostgreSQL 資料庫
- Auth 登入
- RLS 權限控管
- Edge Functions
- Cron 排程
- 少量 Storage 可用於未來合約檔案

### Netlify Free

Netlify Free 適合部署 Nuxt 3 專案，且免費方案有硬性額度限制，超額時會暫停，不會自動產生費用。

本專案以免費方案為優先，因此建議正式部署優先使用 Netlify。

### Vercel Hobby

Vercel 也支援 Nuxt 3 部署，可作為備選方案。

但 Vercel Hobby 較偏個人或非商業用途；若未來系統實際提供屋主使用，可能較接近商業場景，因此不列為首選。

## 建議架構

```text
Nuxt 3
  -> Supabase Auth
  -> Supabase PostgreSQL
  -> Supabase Row Level Security
  -> Supabase Cron / Edge Functions
  -> Netlify Free
```

## 自動提醒設計

未繳房租提醒建議使用 Supabase Cron 執行每日排程。

初版流程：

1. 每日固定時間執行排程。
2. 查詢到期日已到但尚未繳清的租金帳款。
3. 產生提醒紀錄。
4. 初版先顯示在系統內提醒清單。
5. 後續再擴充 Email、LINE 或簡訊通知。

若要維持完全免費，初期不建議使用簡訊，因簡訊服務通常需要付費。

## 免費方案限制與風險

### Supabase Free

需注意資料庫容量、流量、Storage、Edge Function 與 Realtime 使用限制。

以初版房租管理系統來說，資料量主要是文字與金額紀錄，免費額度應足夠支援小型使用情境。

### Netlify Free

需注意每月使用額度。免費方案有硬性上限，超過後服務可能暫停至下個週期或需升級。

### 通知成本

系統內通知可免費完成。

Email 可評估免費額度服務，但不同供應商限制不同。

簡訊通常不適合列入免費初版。

## 結論

本專案正式採用：

```text
Nuxt 3 + Supabase + Netlify Free
```

此方案符合目前需求：

- 可免費開發與部署初版
- 適合關聯式房租資料
- 支援登入與權限
- 支援每日未繳提醒排程
- 未來可逐步擴充通知、報表與權限功能
