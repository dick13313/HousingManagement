export function useAuth() {
  const { client, isConfigured } = useSupabaseClientLite()
  const user = useState<any | null>('auth:user', () => null)
  const loading = useState('auth:loading', () => false)
  const authError = useState('auth:error', () => '')

  async function loadUser() {
    if (!client) return
    const { data } = await client.auth.getUser()
    user.value = data.user
  }

  async function signIn(email: string, password: string) {
    if (!client) return false
    loading.value = true
    authError.value = ''
    const { error } = await client.auth.signInWithPassword({ email, password })
    loading.value = false
    if (error) {
      authError.value = error.message
      return false
    }
    await loadUser()
    return true
  }

  async function signUp(email: string, password: string, displayName: string) {
    if (!client) return false
    loading.value = true
    authError.value = ''
    const { error } = await client.auth.signUp({
      email,
      password,
      options: {
        data: {
          display_name: displayName
        }
      }
    })
    loading.value = false
    if (error) {
      authError.value = error.message
      return false
    }
    await loadUser()
    return true
  }

  async function signOut() {
    if (!client) return
    await client.auth.signOut()
    user.value = null
    await navigateTo('/login')
  }

  return {
    user,
    loading,
    authError,
    isConfigured,
    loadUser,
    signIn,
    signUp,
    signOut
  }
}
