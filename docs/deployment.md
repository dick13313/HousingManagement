# CI/CD 自動發布設定

本專案使用 GitHub Actions 將 `master` 分支自動打包並發布到 Netlify。

## 觸發條件

- Push 到 `master` 分支時自動執行
- 也可以在 GitHub Actions 頁面手動執行 `Deploy to Netlify`

## GitHub Secrets

請在 GitHub Repository 的 `Settings -> Secrets and variables -> Actions` 新增以下 secrets：

| Secret | 說明 |
| --- | --- |
| `NETLIFY_AUTH_TOKEN` | Netlify Personal access token |
| `NETLIFY_SITE_ID` | Netlify Site ID |
| `SUPABASE_URL` | Supabase Project URL，workflow 會映射為 `NUXT_PUBLIC_SUPABASE_URL` |
| `SUPABASE_KEY` | Supabase publishable key / anon public key，workflow 會映射為 `NUXT_PUBLIC_SUPABASE_KEY` |

不要將以上值寫入程式碼或 commit 到 Git。

## 發布流程

Workflow 檔案位於 `.github/workflows/netlify-deploy.yml`，流程如下：

1. Checkout 專案
2. 安裝 Node.js 22
3. 執行 `npm install`
4. 檢查必要 GitHub Secrets 是否存在
5. 使用 Supabase public runtime secrets 執行 `npm run generate`
6. 使用 Netlify CLI 將 `.output/public` 發布到 Netlify production

靜態發布時沒有 Nuxt server runtime，因此 `nuxt.config.ts` 會在 `generate` 當下讀取
`NUXT_PUBLIC_SUPABASE_URL` 與 `NUXT_PUBLIC_SUPABASE_KEY`，並把 public 設定序列化到前端輸出。

GitHub Actions 的部署步驟會使用 `netlify deploy --no-build`，只上傳前一步已完成的
`.output/public`。這樣可以避免 Netlify CLI 讀取 `netlify.toml` 後重新執行一次 build，
導致第二次 build 沒有帶入 GitHub Secrets。

## Netlify 設定

`netlify.toml` 目前設定：

```toml
[build]
  command = "npm run generate"
  publish = ".output/public"
```

若未來改成 Nuxt SSR 或 server functions，需重新檢查 Nuxt Nitro preset 與 Netlify 發布目錄。
