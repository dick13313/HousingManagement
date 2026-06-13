<template>
  <AppShell>
    <section class="page-heading">
      <div>
        <p class="eyebrow">本月收租</p>
        <h1>今天要處理的房租</h1>
      </div>
      <NuxtLink class="primary-link" to="/rent">前往收租</NuxtLink>
    </section>

    <section v-if="!isConfigured" class="notice-panel">
      <strong>尚未連線 Supabase</strong>
      <span>請建立 `.env`，填入 `SUPABASE_URL` 與 `SUPABASE_KEY` 後重新啟動開發伺服器。</span>
    </section>

    <section v-else-if="!user" class="notice-panel">
      <strong>尚未登入</strong>
      <span>請先登入，系統會依照你的角色與屋主權限顯示資料。</span>
      <NuxtLink class="primary-link notice-link" to="/login">前往登入</NuxtLink>
    </section>

    <section class="metrics-grid" aria-label="本月摘要">
      <article class="metric">
        <span>本月應收</span>
        <strong>{{ formatCurrency(summary.totalDue) }}</strong>
        <small>全部租金總額</small>
      </article>
      <article class="metric success">
        <span>本月已收</span>
        <strong>{{ formatCurrency(summary.totalPaid) }}</strong>
        <small>已收到的金額</small>
      </article>
      <article class="metric danger">
        <span>未收金額</span>
        <strong>{{ formatCurrency(summary.totalUnpaid) }}</strong>
        <small>{{ summary.unpaidCount }} 筆帳款未繳清</small>
      </article>
    </section>

    <section class="content-grid">
      <div class="panel wide">
        <div class="panel-header">
          <div>
            <h2>未繳租客</h2>
            <p>先處理這張清單即可</p>
          </div>
          <button class="filter" type="button" @click="loadDashboard">重新整理</button>
        </div>

        <section v-if="loading" class="state-panel" aria-live="polite">
          <strong>資料載入中</strong>
          <p>系統正在整理本月未繳帳款與摘要資訊。</p>
        </section>

        <section v-else-if="unpaidInvoices.length === 0" class="state-panel" aria-live="polite">
          <strong>目前沒有未繳帳款</strong>
          <p>本月帳款都已完成，接下來可前往收租頁建立新月份帳單。</p>
          <div class="state-actions">
            <NuxtLink class="primary-link" to="/rent">前往收租</NuxtLink>
          </div>
        </section>

        <template v-else>
          <div class="mobile-card-list dashboard-mobile-list">
            <article v-for="invoice in unpaidInvoices" :key="`${invoice.id}-mobile`" class="mobile-data-card">
              <div class="mobile-data-card__header">
                <div>
                  <strong>{{ invoice.leases?.tenants?.name || '未指定租客' }}</strong>
                  <p>{{ invoice.leases?.properties?.address || '未指定房屋' }}</p>
                </div>
                <StatusPill :value="invoice.status" :tone="getStatusTone(invoice.status)" />
              </div>

              <dl class="mobile-data-card__details">
                <div>
                  <dt>聯絡電話</dt>
                  <dd>{{ invoice.leases?.tenants?.phone || '未填電話' }}</dd>
                </div>
                <div>
                  <dt>應繳金額</dt>
                  <dd>{{ formatCurrency(invoice.amount_due) }}</dd>
                </div>
                <div>
                  <dt>到期日</dt>
                  <dd>{{ formatDate(invoice.due_on) }}</dd>
                </div>
              </dl>

              <div class="state-actions mobile-row-actions">
                <NuxtLink class="primary-link" to="/rent">前往收租</NuxtLink>
              </div>
            </article>
          </div>

          <div class="table-wrap desktop-table-wrap">
            <table aria-label="未繳帳款資料表">
              <thead>
                <tr>
                  <th>租客</th>
                  <th>房屋</th>
                  <th class="amount">應繳</th>
                  <th>到期日</th>
                  <th>狀態</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="invoice in unpaidInvoices" :key="invoice.id">
                  <td>
                    <strong>{{ invoice.leases?.tenants?.name || '-' }}</strong>
                    <span>{{ invoice.leases?.tenants?.phone || '未填電話' }}</span>
                  </td>
                  <td>{{ invoice.leases?.properties?.address || '-' }}</td>
                  <td class="amount">{{ formatCurrency(invoice.amount_due) }}</td>
                  <td>{{ formatDate(invoice.due_on) }}</td>
                  <td>
                    <StatusPill :value="invoice.status" :tone="getStatusTone(invoice.status)" />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </template>
      </div>

      <aside class="panel side-panel">
        <div class="panel-header compact">
          <div>
            <h2>快速操作</h2>
            <p>常用功能放在這裡</p>
          </div>
        </div>

        <div class="quick-actions">
          <NuxtLink class="quick-button primary" to="/rent">登錄付款</NuxtLink>
          <NuxtLink class="quick-button" to="/reminders">提醒未繳租客</NuxtLink>
          <NuxtLink class="quick-button" to="/tenants">新增租客</NuxtLink>
        </div>

        <div class="mini-chart" aria-label="收款率視覺化">
          <div class="chart-ring">
            <span>{{ collectionRate }}%</span>
          </div>
          <div>
            <strong>已收 {{ collectionRate }}%</strong>
            <p>剩下 {{ summary.unpaidCount }} 筆帳款未繳清</p>
          </div>
        </div>
      </aside>
    </section>
  </AppShell>
</template>

<script setup lang="ts">
const { client, isConfigured } = useSupabaseClientLite()
const { user, loadUser } = useAuth()

const loading = ref(false)
const unpaidInvoices = ref<Record<string, any>[]>([])
const summary = reactive({
  totalDue: 0,
  totalPaid: 0,
  totalUnpaid: 0,
  unpaidCount: 0
})

const collectionRate = computed(() => {
  if (!summary.totalDue) return 0
  return Math.round((summary.totalPaid / summary.totalDue) * 100)
})

async function loadDashboard() {
  if (!client) return
  const { data: sessionData } = await client.auth.getSession()
  if (!sessionData.session) return

  loading.value = true

  const startOfMonth = new Date()
  startOfMonth.setDate(1)
  const month = startOfMonth.toISOString().slice(0, 10)

  const { data } = await client
    .from('rent_invoices')
    .select(`
      id,
      invoice_month,
      amount_due,
      amount_paid,
      due_on,
      status,
      leases (
        tenants ( name, phone ),
        properties ( address )
      )
    `)
    .gte('invoice_month', month)
    .order('due_on', { ascending: true })

  const invoices = data || []
  summary.totalDue = invoices.reduce((sum, invoice) => sum + Number(invoice.amount_due || 0), 0)
  summary.totalPaid = invoices.reduce((sum, invoice) => sum + Number(invoice.amount_paid || 0), 0)
  summary.totalUnpaid = Math.max(summary.totalDue - summary.totalPaid, 0)
  summary.unpaidCount = invoices.filter((invoice) => invoice.status !== 'paid').length
  unpaidInvoices.value = invoices.filter((invoice) => invoice.status !== 'paid')

  loading.value = false
}

onMounted(async () => {
  await loadUser()
  await loadDashboard()
})
</script>
