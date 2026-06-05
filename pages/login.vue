<template>
  <main class="auth-page">
    <section class="auth-card">
      <div class="brand auth-brand">
        <div class="brand-mark" aria-hidden="true">租</div>
        <div>
          <strong>房租管理</strong>
          <span>登入後開始管理收租</span>
        </div>
      </div>

      <div>
        <p class="eyebrow">{{ mode === 'login' ? '登入' : '註冊' }}</p>
        <h1>{{ mode === 'login' ? '歡迎回來' : '建立帳號' }}</h1>
      </div>

      <section v-if="!isConfigured" class="notice-panel">
        <strong>尚未連線 Supabase</strong>
        <span>請先在 `.env` 填入 `SUPABASE_URL` 與 `SUPABASE_KEY`。</span>
      </section>

      <form class="entity-form auth-form" @submit.prevent="submit">
        <label v-if="mode === 'signup'" class="form-field">
          <span>顯示名稱</span>
          <small class="field-help">會顯示在系統內，方便辨識操作者。</small>
          <input v-model="displayName" required autocomplete="name" placeholder="例如：王小美" />
        </label>

        <label class="form-field">
          <span>Email</span>
          <small class="field-help">登入通知與帳號識別都會使用這個 Email。</small>
          <input v-model="email" type="email" required autocomplete="email" inputmode="email" placeholder="name@example.com" />
        </label>

        <label class="form-field">
          <span>密碼</span>
          <small class="field-help">至少 6 碼，建議使用容易辨識的個人密碼規則。</small>
          <input v-model="password" type="password" required minlength="6" :autocomplete="mode === 'login' ? 'current-password' : 'new-password'" placeholder="至少 6 碼" />
        </label>

        <p v-if="authError" class="error-text">{{ authError }}</p>

        <div class="form-actions sticky-form-actions">
          <button class="primary-button" type="submit" :disabled="loading">
            {{ loading ? '處理中' : mode === 'login' ? '登入' : '註冊' }}
          </button>
          <button class="secondary-button" type="button" @click="toggleMode">
            {{ mode === 'login' ? '建立新帳號' : '已有帳號，改登入' }}
          </button>
        </div>
      </form>
    </section>
  </main>
</template>

<script setup lang="ts">
const mode = ref<'login' | 'signup'>('login')
const email = ref('')
const password = ref('')
const displayName = ref('')

const { loading, authError, isConfigured, signIn, signUp, loadUser, user } = useAuth()

function toggleMode() {
  mode.value = mode.value === 'login' ? 'signup' : 'login'
  authError.value = ''
}

async function submit() {
  const ok = mode.value === 'login'
    ? await signIn(email.value, password.value)
    : await signUp(email.value, password.value, displayName.value)

  if (ok) {
    await navigateTo('/')
  }
}

onMounted(async () => {
  await loadUser()
  if (user.value) {
    await navigateTo('/')
  }
})
</script>
