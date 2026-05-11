import { createClient, type SupabaseClient } from '@supabase/supabase-js'

let cachedClient: SupabaseClient | null = null

export function useSupabaseClientLite() {
  const config = useRuntimeConfig()
  const url = config.public.supabaseUrl as string
  const key = config.public.supabaseKey as string

  if (!url || !key) {
    return {
      client: null,
      isConfigured: false
    }
  }

  if (!cachedClient) {
    cachedClient = createClient(url, key)
  }

  return {
    client: cachedClient,
    isConfigured: true
  }
}
