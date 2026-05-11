<template>
  <div class="app-shell">
    <aside class="sidebar" aria-label="主要導覽">
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
        <label class="search">
          <span aria-hidden="true">⌕</span>
          <input type="search" placeholder="搜尋租客或房號" />
        </label>

        <div class="topbar-actions">
          <button class="icon-button" type="button" aria-label="上一個月">‹</button>
          <button class="month-button" type="button">2026 年 5 月</button>
          <button class="icon-button" type="button" aria-label="下一個月">›</button>
          <NuxtLink v-if="!user" class="user-button user-link" to="/login">登入</NuxtLink>
          <button v-else class="user-button" type="button" @click="signOut">
            登出
          </button>
        </div>
      </header>

      <slot />
    </main>
  </div>
</template>

<script setup lang="ts">
const navItems = [
  { to: '/', label: '首頁', icon: '⌂' },
  { to: '/owners', label: '屋主', icon: '人' },
  { to: '/buildings', label: '社區', icon: '棟' },
  { to: '/properties', label: '房屋', icon: '房' },
  { to: '/tenants', label: '租客', icon: '客' },
  { to: '/leases', label: '租約', icon: '約' },
  { to: '/rent', label: '收租', icon: '收' },
  { to: '/payments', label: '付款', icon: '付' },
  { to: '/reminders', label: '提醒', icon: '鈴' }
]

const { user, loadUser, signOut } = useAuth()

onMounted(loadUser)
</script>
