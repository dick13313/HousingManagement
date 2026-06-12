<template>
  <AppShell>
    <section class="page-heading">
      <div>
        <p class="eyebrow">租務管理</p>
        <h1>收租管理</h1>
        <p class="page-helper-text">先選月份，再用屋主與社區篩選縮小範圍；手機上可直接用卡片完成收租。</p>
      </div>
      <div class="topbar-actions">
        <label class="topbar-field">
          <span>月份</span>
          <input v-model="selectedMonth" class="month-input" type="month" aria-label="選擇收租月份" />
        </label>
        <button
          v-if="selectedMonth !== currentMonthValue"
          class="secondary-button"
          type="button"
          @click="resetToCurrentMonth"
        >
          回到本月
        </button>
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
            <p>支援月繳、季繳、半年繳、年繳與自訂月數，收款時會自動補齊期間帳單。</p>
          </div>
          <button class="filter" type="button" @click="loadRentOverview">重新整理</button>
        </div>

        <div class="filter-bar">
          <label class="filter-field">
            <span>屋主</span>
            <select v-model="ownerFilter" aria-label="屋主篩選">
              <option value="">全部</option>
              <option v-for="option in owners" :key="option.value" :value="option.value">
                {{ option.label }}
              </option>
            </select>
          </label>
          <label class="filter-field">
            <span>社區</span>
            <select v-model="buildingFilter" aria-label="社區篩選">
              <option value="">全部</option>
              <option v-for="option in buildings" :key="option.value" :value="option.value">
                {{ option.label }}
              </option>
            </select>
          </label>
          <button class="secondary-button" type="button" @click="clearRentFilters">清除篩選</button>
        </div>

        <p class="filter-summary" aria-live="polite">
          {{ activeFilterSummary }}
        </p>

        <section v-if="error" class="state-panel error-panel" aria-live="polite">
          <strong>收租資料暫時無法顯示</strong>
          <p>{{ error }}</p>
          <button class="secondary-button" type="button" @click="loadRentOverview">重新整理</button>
        </section>

        <section v-else-if="loading" class="state-panel" aria-live="polite">
          <strong>資料載入中</strong>
          <p>系統正在整理本月帳單、付款狀態與可收款項目。</p>
        </section>

        <section v-else-if="filteredRentRows.length === 0" class="state-panel" aria-live="polite">
          <strong>目前沒有符合條件的收租資料</strong>
          <p>可以先清除篩選條件，或建立本月帳單後再回來確認。</p>
          <div class="state-actions">
            <button class="secondary-button" type="button" @click="clearRentFilters">清除篩選</button>
            <button class="primary-button" type="button" :disabled="saving" @click="createMonthlyInvoices">建立本月帳單</button>
          </div>
        </section>

        <template v-else>
          <div class="mobile-card-list rent-mobile-list">
            <article v-for="row in filteredRentRows" :key="`${row.leaseId}-mobile`" class="mobile-data-card">
              <div class="mobile-data-card__header">
                <div>
                  <strong>{{ row.unitNo || row.address }}</strong>
                  <p>{{ row.tenantName }} ・ {{ row.buildingName || '未指定社區' }}</p>
                </div>
                <StatusPill :value="row.status" :tone="getStatusTone(row.status)" />
              </div>

              <dl class="mobile-data-card__details">
                <div>
                  <dt>屋主</dt>
                  <dd>{{ row.ownerName || '未指定屋主' }}</dd>
                </div>
                <div>
                  <dt>繳費週期</dt>
                  <dd>{{ formatPaymentCycle(row.paymentCycleMonths) }}</dd>
                </div>
                <div>
                  <dt>應繳 / 已繳</dt>
                  <dd>{{ formatCurrency(row.amountDue) }} / {{ formatCurrency(row.amountPaid) }}</dd>
                </div>
                <div>
                  <dt>繳款日</dt>
                  <dd>{{ row.dueOn || `每月 ${row.rentDueDay} 日` }}</dd>
                </div>
              </dl>

              <div class="row-actions mobile-row-actions">
                <button
                  v-if="row.invoiceId"
                  class="text-button inline-action"
                  type="button"
                  @click="editInvoice(row)"
                >
                  編輯帳單
                </button>
                <button class="primary-button" type="button" :disabled="saving" @click="openReceiveRent(row)">
                  收租
                </button>
              </div>
            </article>
          </div>

          <div class="table-wrap rent-table-wrap desktop-table-wrap">
            <table class="rent-table" aria-label="收租資料表">
              <thead>
                <tr>
                  <th>房屋 / 社區</th>
                  <th>租客</th>
                  <th>週期</th>
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
                  <td>{{ formatPaymentCycle(row.paymentCycleMonths) }}</td>
                  <td class="amount">{{ formatCurrency(row.amountDue) }}</td>
                  <td class="amount">{{ formatCurrency(row.amountPaid) }}</td>
                  <td>{{ row.dueOn || `每月 ${row.rentDueDay} 日` }}</td>
                  <td>
                    <StatusPill :value="row.status" :tone="getStatusTone(row.status)" />
                  </td>
                  <td>
                    <div class="row-actions">
                      <button
                        v-if="row.invoiceId"
                        class="text-button inline-action"
                        type="button"
                        @click="editInvoice(row)"
                      >
                        編輯
                      </button>
                      <button class="text-button inline-action" type="button" :disabled="saving" @click="openReceiveRent(row)">
                        收租
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </template>
      </section>

      <Teleport to="body">
        <div v-if="editingInvoiceId" class="modal-backdrop" @click.self="cancelInvoiceEdit">
          <section class="modal-panel" role="dialog" aria-modal="true" aria-labelledby="edit-invoice-title">
            <div class="panel-header compact">
              <div>
                <h2 id="edit-invoice-title">修改帳單</h2>
                <p>{{ editingInvoiceTitle }}</p>
              </div>
              <button class="icon-button" type="button" aria-label="關閉修改帳單視窗" @click="cancelInvoiceEdit">×</button>
            </div>

            <form class="entity-form modal-form" @submit.prevent="updateInvoice">
              <label class="form-field">
                <span>應繳金額</span>
                <input v-model="invoiceForm.amount_due" type="number" inputmode="decimal" step="any" min="0" required />
              </label>
              <label class="form-field">
                <span>已繳金額</span>
                <input v-model="invoiceForm.amount_paid" type="number" inputmode="decimal" step="any" min="0" required />
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

      <Teleport to="body">
        <div v-if="receivingRow" class="modal-backdrop" @click.self="cancelReceiveRent">
          <section class="modal-panel" role="dialog" aria-modal="true" aria-labelledby="receive-rent-title">
            <div class="panel-header compact">
              <div>
                <h2 id="receive-rent-title">收租</h2>
                <p>{{ receivingRow.unitNo || receivingRow.address }} / {{ receivingRow.tenantName }}</p>
              </div>
              <button class="icon-button" type="button" aria-label="關閉收租視窗" @click="cancelReceiveRent">×</button>
            </div>

            <form class="entity-form modal-form" @submit.prevent="submitRentPayment">
              <label class="form-field full-span">
                <span>收款期間</span>
                <div class="cycle-buttons">
                  <button
                    v-for="option in quickPaymentMonths"
                    :key="option"
                    class="secondary-button cycle-button"
                    :class="{ active: paymentMonths === option }"
                    type="button"
                    @click="setPaymentMonths(option)"
                  >
                    {{ formatPaymentCycle(option) }}
                  </button>
                </div>
              </label>

              <label class="form-field">
                <span>自訂月數</span>
                <input v-model.number="rentPaymentForm.months" type="number" min="1" max="36" step="1" inputmode="numeric" required />
              </label>
              <label class="form-field">
                <span>付款日期</span>
                <input v-model="rentPaymentForm.paid_on" type="date" required />
              </label>
              <label class="form-field">
                <span>付款方式</span>
                <select v-model="rentPaymentForm.method" required>
                  <option v-for="method in paymentMethods" :key="method.value" :value="method.value">
                    {{ method.label }}
                  </option>
                </select>
              </label>
              <label class="form-field">
                <span>預估收款</span>
                <input :value="receivePreview.amount" type="text" readonly />
              </label>
              <label class="form-field full-span">
                <span>備註</span>
                <textarea v-model="rentPaymentForm.notes" />
              </label>

              <div class="receive-summary full-span">
                <strong>{{ receivePreview.period }}</strong>
                <span>會自動建立缺少的月份帳單，並只補入尚未繳清的差額。</span>
              </div>

              <div class="form-actions">
                <button class="primary-button" type="submit" :disabled="saving">
                  {{ saving ? '收款中' : '確認收款' }}
                </button>
                <button class="secondary-button" type="button" @click="cancelReceiveRent">取消</button>
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
  payment_cycle_months?: number
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
  invoice_month: string
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
  monthlyRent: number
  paymentCycleMonths: number
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
const receivingRow = ref<RentOverviewRow | null>(null)
const invoiceForm = reactive({
  amount_due: 0,
  amount_paid: 0,
  due_on: '',
  status: 'unpaid',
  notes: ''
})
const rentPaymentForm = reactive({
  months: 1,
  paid_on: todayDate(),
  method: 'bank_transfer',
  notes: ''
})

const quickPaymentMonths = [1, 3, 6, 12]
const paymentMethods = [
  { label: '轉帳', value: 'bank_transfer' },
  { label: '現金', value: 'cash' },
  { label: '支票', value: 'check' },
  { label: '其他', value: 'other' }
]

const currentMonthValue = toMonthInputValue(new Date())
const monthStart = computed(() => `${selectedMonth.value}-01`)
const monthLabel = computed(() => selectedMonth.value.replace('-', ' 年 ') + ' 月')
const paymentMonths = computed(() => sanitizePaymentMonths(rentPaymentForm.months))
const receivePreview = computed(() => {
  if (!receivingRow.value) return { amount: formatCurrency(0), period: '' }

  return {
    amount: formatCurrency(receivingRow.value.monthlyRent * paymentMonths.value),
    period: formatMonthPeriod(monthStart.value, paymentMonths.value)
  }
})

const filteredRentRows = computed(() => {
  return rentRows.value.filter((row) => {
    if (ownerFilter.value && row.ownerId !== ownerFilter.value) return false
    if (buildingFilter.value && row.buildingId !== buildingFilter.value) return false
    return true
  }).sort((a, b) => compareUnitNo(a.unitNo || a.address, b.unitNo || b.address))
})

const activeFilterSummary = computed(() => {
  const parts = []
  if (ownerFilter.value) {
    const owner = owners.value.find((option) => option.value === ownerFilter.value)
    parts.push(`屋主：${owner?.label || '已選擇'}`)
  }
  if (buildingFilter.value) {
    const building = buildings.value.find((option) => option.value === buildingFilter.value)
    parts.push(`社區：${building?.label || '已選擇'}`)
  }

  if (!parts.length) {
    return `目前顯示全部 ${filteredRentRows.value.length} 筆收租資料。`
  }

  return `已套用 ${parts.join('、')}，目前顯示 ${filteredRentRows.value.length} 筆資料。`
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
    loadActiveLeases(),
    client
      .from('rent_invoices')
      .select('id, lease_id, invoice_month, amount_due, amount_paid, due_on, status, notes')
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
      monthlyRent: lease.monthly_rent,
      paymentCycleMonths: lease.payment_cycle_months || 1,
      amountDue: invoice?.amount_due ?? lease.monthly_rent,
      amountPaid: invoice?.amount_paid ?? 0,
      rentDueDay: lease.rent_due_day,
      dueOn: invoice?.due_on || '',
      status: invoice?.status || 'unbilled',
      notes: invoice?.notes || ''
    }
  }).sort((a, b) => compareUnitNo(a.unitNo || a.address, b.unitNo || b.address))
}

async function loadActiveLeases() {
  if (!client) return { data: [], error: null }

  const baseSelect = 'id, monthly_rent, rent_due_day, tenants(name), properties(unit_no, address, owner_id, building_id, buildings(name), owners(name))'
  const withPaymentCycle = await client
    .from('leases')
    .select(`id, monthly_rent, rent_due_day, payment_cycle_months, tenants(name), properties(unit_no, address, owner_id, building_id, buildings(name), owners(name))`)
    .eq('status', 'active')
    .order('created_at', { ascending: true })

  if (!withPaymentCycle.error || !isMissingPaymentCycleColumn(withPaymentCycle.error.message)) {
    return withPaymentCycle
  }

  return client
    .from('leases')
    .select(baseSelect)
    .eq('status', 'active')
    .order('created_at', { ascending: true })
}

function isMissingPaymentCycleColumn(message = '') {
  return message.includes('payment_cycle_months') && message.includes('does not exist')
}

function clearRentFilters() {
  ownerFilter.value = ''
  buildingFilter.value = ''
}

function resetToCurrentMonth() {
  selectedMonth.value = currentMonthValue
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

function openReceiveRent(row: RentOverviewRow) {
  receivingRow.value = row
  rentPaymentForm.months = row.paymentCycleMonths || 1
  rentPaymentForm.paid_on = todayDate()
  rentPaymentForm.method = 'bank_transfer'
  rentPaymentForm.notes = ''
}

function cancelReceiveRent() {
  receivingRow.value = null
}

function setPaymentMonths(months: number) {
  rentPaymentForm.months = months
}

async function submitRentPayment() {
  error.value = ''

  if (!client || !receivingRow.value) return

  const row = receivingRow.value
  const months = paymentMonths.value
  const invoiceMonths = getMonthRange(monthStart.value, months)

  saving.value = true

  for (const invoiceMonth of invoiceMonths) {
    const { error: rpcError } = await client.rpc('create_monthly_rent_invoices', {
      target_month: invoiceMonth
    })

    if (rpcError) {
      error.value = rpcError.message
      saving.value = false
      return
    }
  }

  const { data: invoices, error: invoicesError } = await client
    .from('rent_invoices')
    .select('id, lease_id, invoice_month, amount_due, amount_paid, due_on, status, notes')
    .eq('lease_id', row.leaseId)
    .in('invoice_month', invoiceMonths)

  if (invoicesError) {
    error.value = invoicesError.message
    saving.value = false
    return
  }

  const invoicesByMonth = new Map((invoices || []).map((invoice: any) => [invoice.invoice_month, invoice as InvoiceRow]))
  const payableInvoices = invoiceMonths
    .map((invoiceMonth) => invoicesByMonth.get(invoiceMonth))
    .filter((invoice): invoice is InvoiceRow => Boolean(invoice))
    .filter((invoice) => Number(invoice.amount_paid || 0) < Number(invoice.amount_due || 0))

  if (payableInvoices.length === 0) {
    error.value = '選取期間都已繳清，沒有需要補收的金額。'
    saving.value = false
    return
  }

  for (const invoice of payableInvoices) {
    const amount = Math.max(Number(invoice.amount_due || 0) - Number(invoice.amount_paid || 0), 0)
    if (amount <= 0) continue

    const { error: paymentError } = await client
      .from('payments')
      .insert({
        rent_invoice_id: invoice.id,
        paid_on: rentPaymentForm.paid_on,
        amount,
        method: rentPaymentForm.method,
        notes: buildPaymentNote(invoice.invoice_month)
      })

    if (paymentError) {
      error.value = paymentError.message
      saving.value = false
      return
    }
  }

  const missingMonths = invoiceMonths.filter((invoiceMonth) => !invoicesByMonth.has(invoiceMonth))
  saving.value = false
  cancelReceiveRent()
  await loadRentOverview()

  if (missingMonths.length > 0) {
    error.value = `部分月份未建立帳單，可能超出租約期間：${missingMonths.map(formatInvoiceMonthLabel).join('、')}`
  }
}

function buildPaymentNote(invoiceMonth: string) {
  const baseNote = `收租頁面收取 ${formatInvoiceMonthLabel(invoiceMonth)} 租金`
  return rentPaymentForm.notes ? `${baseNote}；${rentPaymentForm.notes}` : baseNote
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

function formatPaymentCycle(months: number) {
  if (months === 1) return '月繳'
  if (months === 3) return '季繳'
  if (months === 6) return '半年繳'
  if (months === 12) return '年繳'
  return `${months || 1} 個月`
}

function sanitizePaymentMonths(value: number) {
  const months = Number(value || 1)
  if (!Number.isFinite(months)) return 1
  return Math.min(Math.max(Math.trunc(months), 1), 36)
}

function getMonthRange(startMonth: string, months: number) {
  return Array.from({ length: months }, (_, index) => formatMonthStart(addMonths(parseMonthStart(startMonth), index)))
}

function formatMonthPeriod(startMonth: string, months: number) {
  const range = getMonthRange(startMonth, months)
  if (range.length === 1) return formatInvoiceMonthLabel(range[0])
  return `${formatInvoiceMonthLabel(range[0])} - ${formatInvoiceMonthLabel(range[range.length - 1])}`
}

function parseMonthStart(value: string) {
  const [year, month] = value.slice(0, 7).split('-').map(Number)
  return new Date(year, month - 1, 1)
}

function addMonths(date: Date, months: number) {
  return new Date(date.getFullYear(), date.getMonth() + months, 1)
}

function formatMonthStart(date: Date) {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  return `${year}-${month}-01`
}

function formatInvoiceMonthLabel(invoiceMonth: string) {
  const [year, month] = invoiceMonth.slice(0, 7).split('-')
  return `${year} 年 ${Number(month)} 月`
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
