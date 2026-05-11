<template>
  <AppShell>
    <section class="page-heading">
      <div>
        <p class="eyebrow">租務管理</p>
        <h1>收租管理</h1>
      </div>
      <div class="topbar-actions">
        <input v-model="selectedMonth" class="month-input" type="month" />
        <button class="primary-button" type="button" :disabled="saving" @click="createMonthlyInvoices">
          {{ saving ? '建立中' : '建立本月帳單' }}
        </button>
      </div>
    </section>

    <section v-if="!isConfigured" class="notice-panel">
      <strong>尚未連線 Supabase</strong>
      <span>請建立 `.env`，填入 `SUPABASE_URL` 與 `SUPABASE_KEY` 後重新啟動開發伺服器。</span>
    </section>

    <section v-else-if="!user" class="notice-panel">
      <strong>尚未登入</strong>
      <span>請先登入後查看每月收租狀態。</span>
      <NuxtLink class="primary-link notice-link" to="/login">前往登入</NuxtLink>
    </section>

    <template v-else>
      <section class="metrics-grid">
        <article class="metric">
          <span>本月應收</span>
          <strong>{{ formatCurrency(summary.amountDue) }}</strong>
          <small>{{ summary.total }} 間出租房屋</small>
        </article>
        <article class="metric success">
          <span>已收金額</span>
          <strong>{{ formatCurrency(summary.amountPaid) }}</strong>
          <small>{{ summary.paid }} 筆已繳清</small>
        </article>
        <article class="metric danger">
          <span>未收金額</span>
          <strong>{{ formatCurrency(summary.amountUnpaid) }}</strong>
          <small>{{ summary.unpaid }} 筆需要追蹤</small>
        </article>
      </section>

      <section class="panel">
        <div class="panel-header">
          <div>
            <h2>{{ monthLabel }} 收租狀態</h2>
            <p>每間出租房屋每個月都會列在這裡，方便一眼確認誰還沒繳。</p>
          </div>
          <button class="filter" type="button" @click="loadRentOverview">重新整理</button>
        </div>

        <div class="filter-bar">
          <label class="filter-field">
            <span>屋主</span>
            <select v-model="ownerFilter">
              <option value="">全部</option>
              <option v-for="option in owners" :key="option.value" :value="option.value">
                {{ option.label }}
              </option>
            </select>
          </label>
          <label class="filter-field">
            <span>社區</span>
            <select v-model="buildingFilter">
              <option value="">全部</option>
              <option v-for="option in buildings" :key="option.value" :value="option.value">
                {{ option.label }}
              </option>
            </select>
          </label>
          <button class="secondary-button" type="button" @click="clearRentFilters">清除篩選</button>
        </div>

        <p v-if="error" class="error-text">{{ error }}</p>
        <p v-if="loading" class="empty-text">資料載入中...</p>
        <p v-else-if="filteredRentRows.length === 0" class="empty-text">目前沒有符合條件的收租資料。</p>

        <div v-else class="table-wrap rent-table-wrap">
          <table class="rent-table">
            <thead>
              <tr>
                <th>房屋 / 社區</th>
                <th>租客</th>
                <th class="amount">應繳</th>
                <th class="amount">已繳</th>
                <th>繳款日</th>
                <th>狀態</th>
                <th>操作</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in filteredRentRows" :key="row.leaseId">
                <td>
                  <strong>{{ row.unitNo || row.address }}</strong>
                  <span>{{ row.buildingName || '未指定社區' }}・{{ row.address }}</span>
                </td>
                <td>
                  <strong>{{ row.tenantName }}</strong>
                  <span>{{ row.ownerName || '未指定屋主' }}</span>
                </td>
                <td class="amount">{{ formatCurrency(row.amountDue) }}</td>
                <td class="amount">{{ formatCurrency(row.amountPaid) }}</td>
                <td>{{ row.dueOn || `每月 ${row.rentDueDay} 日` }}</td>
                <td>
                  <StatusPill :value="row.status" :tone="getStatusTone(row.status)" />
                </td>
                <td>
                  <div v-if="row.invoiceId" class="row-actions">
                    <button class="text-button inline-action" type="button" @click="editInvoice(row)">
                      編輯
                    </button>
                    <button
                      class="text-button inline-action"
                      type="button"
                      :disabled="saving || row.status === 'paid'"
                      @click="confirmPaid(row)"
                    >
                      {{ row.status === 'paid' ? '已繳款' : '確認已繳' }}
                    </button>
                  </div>
                  <span v-else class="empty-text">待建帳</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <Teleport to="body">
        <div v-if="editingInvoiceId" class="modal-backdrop" @click.self="cancelInvoiceEdit">
          <section class="modal-panel">
            <div class="panel-header compact">
              <div>
                <h2>修改帳單</h2>
                <p>{{ editingInvoiceTitle }}</p>
              </div>
              <button class="icon-button" type="button" @click="cancelInvoiceEdit">×</button>
            </div>

            <form class="entity-form modal-form" @submit.prevent="updateInvoice">
              <label class="form-field">
                <span>應繳金額</span>
                <input v-model="invoiceForm.amount_due" type="number" required />
              </label>
              <label class="form-field">
                <span>已繳金額</span>
                <input v-model="invoiceForm.amount_paid" type="number" required />
              </label>
              <label class="form-field">
                <span>到期日</span>
                <input v-model="invoiceForm.due_on" type="date" required />
              </label>
              <label class="form-field">
                <span>狀態</span>
                <select v-model="invoiceForm.status" required>
                  <option value="unpaid">未繳</option>
                  <option value="partial">部分繳</option>
                  <option value="paid">已繳</option>
                  <option value="overdue">逾期</option>
                </select>
              </label>
              <label class="form-field">
                <span>備註</span>
                <textarea v-model="invoiceForm.notes" />
              </label>
              <div class="form-actions">
                <button class="primary-button" type="submit" :disabled="saving">
                  {{ saving ? '儲存中' : '儲存修改' }}
                </button>
                <button class="secondary-button" type="button" @click="cancelInvoiceEdit">取消</button>
              </div>
            </form>
          </section>
        </div>
      </Teleport>
    </template>
  </AppShell>
</template>

<script setup lang="ts">
type LeaseRow = {
  id: string
  monthly_rent: number
  rent_due_day: number
  tenants?: { name?: string }
  properties?: {
    unit_no?: string
    address?: string
    owner_id?: string
    building_id?: string
    buildings?: { name?: string }
    owners?: { name?: string }
  }
}

type InvoiceRow = {
  id: string
  lease_id: string
  amount_due: number
  amount_paid: number
  due_on: string
  status: string
  notes?: string
}

type RentOverviewRow = {
  leaseId: string
  invoiceId: string | null
  unitNo: string
  address: string
  buildingName: string
  buildingId: string
  ownerName: string
  ownerId: string
  tenantName: string
  amountDue: number
  amountPaid: number
  rentDueDay: number
  dueOn: string
  status: string
  notes: string
}

const { client, isConfigured } = useSupabaseClientLite()
const { user, loadUser } = useAuth()
const { owners, buildings } = useReferenceOptions()

const selectedMonth = ref(toMonthInputValue(new Date()))
const ownerFilter = ref('')
const buildingFilter = ref('')
const rentRows = ref<RentOverviewRow[]>([])
const loading = ref(false)
const saving = ref(false)
const error = ref('')
const editingInvoiceId = ref('')
const editingInvoiceTitle = ref('')
const invoiceForm = reactive({
  amount_due: 0,
  amount_paid: 0,
  due_on: '',
  status: 'unpaid',
  notes: ''
})

const monthStart = computed(() => `${selectedMonth.value}-01`)
const monthLabel = computed(() => selectedMonth.value.replace('-', ' 年 ') + ' 月')

const filteredRentRows = computed(() => {
  return rentRows.value.filter((row) => {
    if (ownerFilter.value && row.ownerId !== ownerFilter.value) return false
    if (buildingFilter.value && row.buildingId !== buildingFilter.value) return false
    return true
  }).sort((a, b) => compareUnitNo(a.unitNo || a.address, b.unitNo || b.address))
})

const summary = computed(() => {
  const rows = filteredRentRows.value
  const amountDue = rows.reduce((total, row) => total + row.amountDue, 0)
  const amountPaid = rows.reduce((total, row) => total + row.amountPaid, 0)
  const paid = rows.filter((row) => row.status === 'paid').length
  const unpaid = rows.filter((row) => row.status !== 'paid').length

  return {
    total: rows.length,
    paid,
    unpaid,
    amountDue,
    amountPaid,
    amountUnpaid: Math.max(amountDue - amountPaid, 0)
  }
})

watch(selectedMonth, () => {
  loadRentOverview()
})

async function loadRentOverview() {
  error.value = ''

  if (!client) return

  const { data: sessionData } = await client.auth.getSession()
  if (!sessionData.session) {
    rentRows.value = []
    return
  }

  loading.value = true

  const [leasesResult, invoicesResult] = await Promise.all([
    client
      .from('leases')
      .select('id, monthly_rent, rent_due_day, tenants(name), properties(unit_no, address, owner_id, building_id, buildings(name), owners(name))')
      .eq('status', 'active')
      .order('created_at', { ascending: true }),
    client
      .from('rent_invoices')
      .select('id, lease_id, amount_due, amount_paid, due_on, status, notes')
      .eq('invoice_month', monthStart.value)
  ])

  loading.value = false

  if (leasesResult.error || invoicesResult.error) {
    error.value = leasesResult.error?.message || invoicesResult.error?.message || '資料載入失敗。'
    return
  }

  const invoicesByLease = new Map<string, InvoiceRow>()
  for (const invoice of invoicesResult.data || []) {
    invoicesByLease.set(invoice.lease_id, invoice as InvoiceRow)
  }

  rentRows.value = ((leasesResult.data || []) as LeaseRow[]).map((lease) => {
    const invoice = invoicesByLease.get(lease.id)
    const property = lease.properties || {}

    return {
      leaseId: lease.id,
      invoiceId: invoice?.id || null,
      unitNo: property.unit_no || '',
      address: property.address || '',
      buildingName: property.buildings?.name || '',
      buildingId: property.building_id || '',
      ownerName: property.owners?.name || '',
      ownerId: property.owner_id || '',
      tenantName: lease.tenants?.name || '未指定租客',
      amountDue: invoice?.amount_due ?? lease.monthly_rent,
      amountPaid: invoice?.amount_paid ?? 0,
      rentDueDay: lease.rent_due_day,
      dueOn: invoice?.due_on || '',
      status: invoice?.status || 'unbilled',
      notes: invoice?.notes || ''
    }
  }).sort((a, b) => compareUnitNo(a.unitNo || a.address, b.unitNo || b.address))
}

function clearRentFilters() {
  ownerFilter.value = ''
  buildingFilter.value = ''
}

function editInvoice(row: RentOverviewRow) {
  if (!row.invoiceId) return

  editingInvoiceId.value = row.invoiceId
  editingInvoiceTitle.value = `${row.unitNo || row.address} / ${row.tenantName}`
  invoiceForm.amount_due = row.amountDue
  invoiceForm.amount_paid = row.amountPaid
  invoiceForm.due_on = row.dueOn
  invoiceForm.status = row.status === 'unbilled' ? 'unpaid' : row.status
  invoiceForm.notes = row.notes
}

function cancelInvoiceEdit() {
  editingInvoiceId.value = ''
  editingInvoiceTitle.value = ''
}

async function updateInvoice() {
  error.value = ''

  if (!client || !editingInvoiceId.value) return

  saving.value = true
  const { error: updateError } = await client
    .from('rent_invoices')
    .update({
      amount_due: Number(invoiceForm.amount_due),
      amount_paid: Number(invoiceForm.amount_paid),
      due_on: invoiceForm.due_on,
      status: invoiceForm.status,
      notes: invoiceForm.notes || null
    })
    .eq('id', editingInvoiceId.value)

  saving.value = false

  if (updateError) {
    error.value = updateError.message
    return
  }

  cancelInvoiceEdit()
  await loadRentOverview()
}

async function confirmPaid(row: RentOverviewRow) {
  error.value = ''

  if (!client || !row.invoiceId) return
  if (row.status === 'paid') return

  const remainingAmount = Math.max(row.amountDue - row.amountPaid, 0)
  const ok = window.confirm(`確認「${row.unitNo || row.address} / ${row.tenantName}」已繳款 ${formatCurrency(remainingAmount || row.amountDue)}？`)
  if (!ok) return

  saving.value = true

  if (remainingAmount > 0) {
    const { error: paymentError } = await client
      .from('payments')
      .insert({
        rent_invoice_id: row.invoiceId,
        paid_on: todayDate(),
        amount: remainingAmount,
        method: 'bank_transfer',
        notes: '收租頁面一鍵確認已繳'
      })

    if (paymentError) {
      error.value = paymentError.message
      saving.value = false
      return
    }
  }

  const { error: invoiceError } = await client
    .from('rent_invoices')
    .update({
      amount_paid: row.amountDue,
      status: 'paid'
    })
    .eq('id', row.invoiceId)

  saving.value = false

  if (invoiceError) {
    error.value = invoiceError.message
    return
  }

  await loadRentOverview()
}

async function createMonthlyInvoices() {
  error.value = ''

  if (!client) {
    error.value = '尚未設定 Supabase 連線資訊。'
    return
  }

  saving.value = true
  const { error: rpcError } = await client.rpc('create_monthly_rent_invoices', {
    target_month: monthStart.value
  })
  saving.value = false

  if (rpcError) {
    error.value = rpcError.message
    return
  }

  await loadRentOverview()
}

function toMonthInputValue(date: Date) {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  return `${year}-${month}`
}

function todayDate() {
  const now = new Date()
  const year = now.getFullYear()
  const month = String(now.getMonth() + 1).padStart(2, '0')
  const day = String(now.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

function compareUnitNo(a: string, b: string) {
  return a.localeCompare(b, 'zh-TW', {
    numeric: true,
    sensitivity: 'base'
  })
}

onMounted(async () => {
  await loadUser()
  await loadRentOverview()
})
</script>
