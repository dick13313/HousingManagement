export default defineNuxtConfig({
  compatibilityDate: '2026-05-07',
  devtools: { enabled: true },
  css: ['~/assets/css/main.css'],
  runtimeConfig: {
    public: {
      supabaseUrl: process.env.NUXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL || '',
      supabaseKey: process.env.NUXT_PUBLIC_SUPABASE_KEY || process.env.SUPABASE_KEY || ''
    }
  },
  app: {
    head: {
      title: '房租管理系統',
      htmlAttrs: {
        lang: 'zh-Hant'
      },
      meta: [
        { name: 'viewport', content: 'width=device-width, initial-scale=1' },
        {
          name: 'description',
          content: '以屋主收租管理為核心的房租管理系統'
        }
      ]
    }
  }
})
