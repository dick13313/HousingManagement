<template>
  <AppShell>
    <section class="page-heading">
      <div>
        <p class="eyebrow">系統管理</p>
        <h1>帳號管理</h1>
      </div>
      <button class="filter" type="button" @click="load">重新整理</button>
    </section>

    <section v-if="!isConfigured" class="notice-panel">
      <strong>尚未連線 Supabase</strong>
      <span>請建立 `.env`，填入 `SUPABASE_URL` 與 `SUPABASE_KEY` 後重新啟動開發伺服器。</span>
    </section>

    <section v-else-if="!user" class="notice-panel">
      <strong>尚未登入</strong>
      <span>請先登入 admin 帳號後再管理使用者。</span>
      <NuxtLink class="primary-link notice-link" to="/login">前往登入</NuxtLink>
    </section>

    <section v-else-if="currentRole && currentRole !== 'admin'" class="notice-panel">
      <strong>沒有帳號管理權限</strong>
      <span>只有 admin 可以開通帳號、調整角色與綁定屋主。</span>
    </section>

    <section v-else class="panel">
      <div class="panel-header">
        <div>
          <h2>使用者列表</h2>
          <p>註冊後的帳號會出現在這裡，設定角色後才會取得對應資料權限。</p>
        </div>
      </div>

      <div class="filter-bar">
        <label class="filter-field">
          <span>搜尋</span>
          <input v-model="keyword" type="search" placeholder="Email 或顯示名稱" />
        </label>

        <label class="filter-field">
          <span>角色</span>
          <select v-model="roleFilter">
            <option value="">全部</option>
            <option value="admin">Admin</option>
            <option value="manager">Manager</option>
            <option value="owner">Owner</option>
          </select>
        </label>

        <label class="filter-field">
          <span>屋主</span>
          <select v-model="ownerFilter">
            <option value="">全部</option>
            <option value="__none">未綁定</option>
            <option v-for="owner in owners" :key="owner.id" :value="owner.id">
              {{ owner.name }}
            </option>
          </select>
        </label>

        <button class="secondary-button" type="button" @click="clearFilters">清除篩選</button>
      </div>

      <p v-if="error" class="error-text">{{ error }}</p>
      <p v-if="loading" class="empty-text">資料載入中...</p>
      <p v-else-if="filteredProfiles.length === 0" class="empty-text">目前沒有符合條件的帳號。</p>

      <div v-else class="table-wrap">
        <table>
          <thead>
            <tr>
              <th>帳號</th>
              <th>角色</th>
              <th>綁定屋主</th>
              <th>建立時間</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="profile in filteredProfiles" :key="profile.id">
              <td>
                <strong>{{ profile.display_name || profile.email || '未命名帳號' }}</strong>
                <span>{{ profile.email || profile.id }}</span>
              </td>
              <td>
                <StatusPill :value="roleLabel(profile.role)" :tone="roleTone(profile.role)" />
              </td>
              <td>
                <span>{{ ownerName(profile.owner_id) }}</span>
              </td>
              <td>
                <span>{{ formatDate(profile.created_at) }}</span>
              </td>
              <td>
                <button class="text-button inline-action" type="button" :disabled="saving" @click="openEdit(profile)">
                  編輯
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <Teleport to="body">
      <div v-if="editingProfile" class="modal-backdrop" @click.self="closeEdit">
        <section class="modal-panel">
          <div class="panel-header compact">
            <div>
              <h2>編輯帳號</h2>
              <p>{{ editingProfile.email || editingProfile.id }}</p>
            </div>
            <button class="icon-button" type="button" @click="closeEdit">×</button>
          </div>

          <form class="entity-form modal-form" @submit.prevent="saveProfile">
            <label class="form-field">
              <span>顯示名稱</span>
              <input v-model="form.display_name" />
            </label>

            <label class="form-field">
              <span>角色</span>
              <select v-model="form.role" required>
                <option value="admin">Admin</option>
                <option value="manager">Manager</option>
                <option value="owner">Owner</option>
              </select>
            </label>

            <label class="form-field">
              <span>綁定屋主</span>
              <select v-model="form.owner_id" :disabled="form.role !== 'owner'" :required="form.role === 'owner'">
                <option value="">未綁定</option>
                <option v-for="owner in owners" :key="owner.id" :value="owner.id">
                  {{ owner.name }}
                </option>
              </select>
            </label>

            <section class="notice-panel account-note">
              <strong>{{ form.role === 'owner' ? 'Owner 需要綁定屋主' : 'Admin / Manager 會看見全部資料' }}</strong>
              <span>登入 Email 是否已驗證仍需到 Supabase Authentication 的 Users 頁面確認。</span>
            </section>

            <div class="form-actions">
              <button class="primary-button" type="submit" :disabled="saving">
                {{ saving ? '儲存中' : '儲存修改' }}
              </button>
              <button class="secondary-button" type="button" @click="closeEdit">取消</button>
            </div>
          </form>
        </section>
      </div>
    </Teleport>
  </AppShell>
</template>

<script setup lang="ts">
type AppRole = 'admin' | 'manager' | 'owner'

type Profile = {
  id: string
  email: string | null
  display_name: string | null
  role: AppRole
  owner_id: string | null
  created_at: string
}

type Owner = {
  id: string
  name: string
}

const { client, isConfigured } = useSupabaseClientLite()
const { user, loadUser } = useAuth()

const profiles = ref<Profile[]>([])
const owners = ref<Owner[]>([])
const currentRole = ref('')
const loading = ref(false)
const saving = ref(false)
const error = ref('')
const keyword = ref('')
const roleFilter = ref('')
const ownerFilter = ref('')
const editingProfile = ref<Profile | null>(null)
const form = reactive({
  display_name: '',
  role: 'owner' as AppRole,
  owner_id: ''
})

const filteredProfiles = computed(() => {
  const search = keyword.value.trim().toLowerCase()

  return profiles.value.filter((profile) => {
    if (search) {
      const label = `${profile.email || ''} ${profile.display_name || ''}`.toLowerCase()
      if (!label.includes(search)) return false
    }

    if (roleFilter.value && profile.role !== roleFilter.value) return false
    if (ownerFilter.value === '__none' && profile.owner_id) return false
    if (ownerFilter.value && ownerFilter.value !== '__none' && profile.owner_id !== ownerFilter.value) return false

    return true
  })
})

watch(
  () => form.role,
  (role) => {
    if (role !== 'owner') {
      form.owner_id = ''
    }
  }
)

function clearFilters() {
  keyword.value = ''
  roleFilter.value = ''
  ownerFilter.value = ''
}

function openEdit(profile: Profile) {
  editingProfile.value = profile
  form.display_name = profile.display_name || ''
  form.role = profile.role
  form.owner_id = profile.owner_id || ''
}

function closeEdit() {
  editingProfile.value = null
  form.display_name = ''
  form.role = 'owner'
  form.owner_id = ''
}

function ownerName(ownerId: string | null) {
  if (!ownerId) return '未綁定'
  return owners.value.find((owner) => owner.id === ownerId)?.name || '未知屋主'
}

function roleLabel(role: AppRole) {
  const labels: Record<AppRole, string> = {
    admin: 'Admin',
    manager: 'Manager',
    owner: 'Owner'
  }

  return labels[role] || role
}

function roleTone(role: AppRole) {
  if (role === 'admin') return 'danger'
  if (role === 'manager') return 'warning'
  return 'success'
}

function formatDate(value: string) {
  if (!value) return '-'
  return new Intl.DateTimeFormat('zh-TW', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).format(new Date(value))
}

async function loadCurrentRole() {
  currentRole.value = ''

  if (!client || !user.value) return

  const { data, error: profileError } = await client
    .from('profiles')
    .select('role')
    .eq('id', user.value.id)
    .single()

  if (profileError) {
    error.value = profileError.message
    return
  }

  currentRole.value = data?.role || ''
}

async function load() {
  error.value = ''

  if (!client) {
    profiles.value = []
    owners.value = []
    return
  }

  await loadUser()

  if (!user.value) {
    profiles.value = []
    owners.value = []
    return
  }

  loading.value = true
  await loadCurrentRole()

  if (currentRole.value !== 'admin') {
    loading.value = false
    profiles.value = []
    owners.value = []
    return
  }

  const [profilesResult, ownersResult] = await Promise.all([
    client
      .from('profiles')
      .select('id, email, display_name, role, owner_id, created_at')
      .order('created_at', { ascending: false }),
    client
      .from('owners')
      .select('id, name')
      .order('name')
  ])

  loading.value = false

  if (profilesResult.error) {
    error.value = profilesResult.error.message
    return
  }

  if (ownersResult.error) {
    error.value = ownersResult.error.message
    return
  }

  profiles.value = profilesResult.data || []
  owners.value = ownersResult.data || []
}

async function saveProfile() {
  if (!client || !editingProfile.value) return

  if (form.role === 'owner' && !form.owner_id) {
    error.value = 'Owner 角色需要選擇一位屋主。'
    return
  }

  saving.value = true
  error.value = ''

  const { error: updateError } = await client
    .from('profiles')
    .update({
      display_name: form.display_name || null,
      role: form.role,
      owner_id: form.role === 'owner' ? form.owner_id : null
    })
    .eq('id', editingProfile.value.id)

  saving.value = false

  if (updateError) {
    error.value = updateError.message
    return
  }

  closeEdit()
  await load()
}

onMounted(load)
</script>
