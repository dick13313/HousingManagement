<template>
  <div class="app-shell">
    <aside class="sidebar desktop-sidebar" aria-label="主要導覽">
      <div class="brand">
        <div class="brand-mark" aria-hidden="true">租</div>
        <div>
          <strong>房租管理</strong>
          <span>簡易收租工作台</span>
        </div>
      </div>

      <nav class="nav">
        <NuxtLink
          v-for="item in navItems"
          v-show="!item.adminOnly || currentRole === 'admin'"
          :key="item.to"
          class="nav-item"
          active-class="active"
          :to="item.to"
        >
          <span class="nav-icon" aria-hidden="true">{{ item.icon }}</span>
          {{ item.label }}
        </NuxtLink>
      </nav>
    </aside>

    <main class="main">
      <header class="topbar">
        <section class="topbar-context" :aria-label="`${currentNavItem.label} 頁面資訊`">
          <p class="eyebrow topbar-eyebrow">{{ currentNavItem.label }}</p>
          <h1 class="topbar-title">{{ pageTitle }}</h1>
          <p class="topbar-caption">{{ pageCaption }}</p>
        </section>

        <div class="topbar-actions">
          <div class="topbar-badge" aria-label="今日日期">{{ todayLabel }}</div>
          <NuxtLink v-if="!user" class="user-button user-link" to="/login">登入</NuxtLink>
          <button v-else class="user-button" type="button" @click="signOut">
            登出
          </button>
        </div>
      </header>

      <slot />
    </main>

    <nav class="mobile-tabbar" aria-label="手機主要導覽">
      <NuxtLink
        v-for="item in mobilePrimaryItems"
        :key="item.to"
        class="mobile-tab"
        active-class="active"
        :to="item.to"
        @click="showMobileMore = false"
      >
        <span class="mobile-tab-icon" aria-hidden="true">{{ item.icon }}</span>
        <span>{{ item.label }}</span>
      </NuxtLink>

      <button
        class="mobile-tab"
        type="button"
        :class="{ active: showMobileMore }"
        :aria-expanded="showMobileMore"
        aria-controls="mobile-more-menu"
        @click="showMobileMore = !showMobileMore"
      >
        <span class="mobile-tab-icon" aria-hidden="true">⋯</span>
        <span>更多</span>
      </button>
    </nav>

    <Teleport to="body">
      <div v-if="showMobileMore" class="mobile-menu-backdrop" @click.self="showMobileMore = false">
        <section id="mobile-more-menu" class="mobile-menu-panel" aria-label="更多功能">
          <div class="mobile-menu-header">
            <div class="mobile-menu-copy">
              <strong>更多功能</strong>
              <span>{{ pageTitle }}</span>
              <small>{{ user ? '已登入，可切換其他管理頁面。' : '尚未登入，登入後可管理資料。' }}</small>
            </div>
            <button class="icon-button" type="button" @click="showMobileMore = false">×</button>
          </div>

          <div class="mobile-menu-grid">
            <NuxtLink
              v-for="item in mobileMoreItems"
              :key="item.to"
              class="mobile-menu-item"
              active-class="active"
              :to="item.to"
              @click="showMobileMore = false"
            >
              <span class="nav-icon" aria-hidden="true">{{ item.icon }}</span>
              {{ item.label }}
            </NuxtLink>
          </div>
        </section>
      </div>
    </Teleport>
  </div>
</template>

<script setup lang="ts">
const route = useRoute()

const navItems = [
  { to: '/', label: '首頁', icon: '⌂' },
  { to: '/owners', label: '屋主', icon: '人' },
  { to: '/buildings', label: '社區', icon: '棟' },
  { to: '/properties', label: '房屋', icon: '房' },
  { to: '/tenants', label: '租客', icon: '客' },
  { to: '/leases', label: '租約', icon: '約' },
  { to: '/rent', label: '收租', icon: '收' },
  { to: '/payments', label: '付款', icon: '付' },
  { to: '/reports', label: '報表', icon: '表' },
  { to: '/reminders', label: '提醒', icon: '鈴' },
  { to: '/accounts', label: '帳號', icon: '權', adminOnly: true }
]

const { user, loadUser, signOut } = useAuth()
const { client } = useSupabaseClientLite()
const currentRole = ref('')
const showMobileMore = ref(false)

const todayLabel = ref('')

onMounted(() => {
  todayLabel.value = new Intl.DateTimeFormat('zh-TW', {
    month: 'long',
    day: 'numeric',
    weekday: 'short'
  }).format(new Date())
})

const availableNavItems = computed(() => {
  return navItems.filter((item) => !item.adminOnly || currentRole.value === 'admin')
})

const currentNavItem = computed(() => {
  return navItems.find((item) => item.to === route.path) || navItems[0]
})

const pageTitle = computed(() => {
  if (route.path === '/') return '優先處理本月未繳租金與常用操作'
  if (route.path === '/rent') return '查看本月收租進度並補收未繳帳款'
  if (route.path === '/reports') return '彙整年度租金收入與匯出報表'
  if (route.path === '/login') return '登入後即可查看角色對應的管理資料'
  return `集中管理${currentNavItem.value.label}資料與日常操作`
})

const pageCaption = computed(() => {
  if (route.path === '/') return '首頁會先列出最需要處理的帳款，適合每日開工先查看。'
  if (route.path === '/rent') return '先選月份，再用篩選縮小範圍，可直接在列表內收租或編輯帳單。'
  if (route.path === '/reports') return '年度報表支援先篩選屋主與社區，再匯出 CSV。'
  if (route.path === '/login') return '如果帳號尚未建立，先切換成註冊模式建立使用者。'
  return '可用上方主要操作與下方手機分頁快速切換工作流程。'
})

const mobilePrimaryRoutes = ['/', '/rent', '/properties', '/tenants', '/reports']

const mobilePrimaryItems = computed(() => {
  return availableNavItems.value.filter((item) => mobilePrimaryRoutes.includes(item.to))
})

const mobileMoreItems = computed(() => {
  return availableNavItems.value.filter((item) => !mobilePrimaryRoutes.includes(item.to))
})

watch(() => route.path, () => {
  showMobileMore.value = false
})

async function loadCurrentRole() {
  await loadUser()

  if (!client || !user.value) {
    currentRole.value = ''
    return
  }

  const { data } = await client
    .from('profiles')
    .select('role')
    .eq('id', user.value.id)
    .single()

  currentRole.value = data?.role || ''
}

onMounted(loadCurrentRole)
</script>
