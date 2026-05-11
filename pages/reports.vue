<template>
  <AppShell>
    <section class="page-heading">
      <div>
        <p class="eyebrow">年度報稅</p>
        <h1>租金收入報表</h1>
      </div>
      <div class="topbar-actions">
        <input v-model="selectedYear" class="month-input year-input" type="number" min="2000" max="2100" />
        <button class="primary-button" type="button" :disabled="loading || reportRows.length === 0" @click="exportCsv">
          匯出 CSV
        </button>
      </div>
    </section>

    <section v-if="!isConfigured" class="notice-panel">
      <strong>尚未連線 Supabase</strong>
      <span>請建立 `.env`，填入 `SUPABASE_URL` 與 `SUPABASE_KEY` 後重新啟動開發伺服器。</span>
    </section>

    <section v-else-if="!user" class="notice-panel">
      <strong>尚未登入</strong>
      <span>請先登入後匯出年度租金收入。</span>
      <NuxtLink class="primary-link notice-link" to="/login">前往登入</NuxtLink>
    </section>

    <template v-else>
      <section class="metrics-grid">
        <article class="metric">
          <span>年度已收租金</span>
          <strong>{{ formatCurrency(summary.totalPaid) }}</strong>
          <small>{{ selectedYear }} 年實際已收金額</small>
        </article>
        <article class="metric success">
          <span>報表房屋數</span>
          <strong>{{ summary.propertyCount }}</strong>
          <small>有帳款紀錄的房屋</small>
        </article>
        <article class="metric danger">
          <span>屋主數</span>
          <strong>{{ summary.ownerCount }}</strong>
          <small>可依屋主篩選匯出</small>
        </article>
      </section>

      <section class="panel">
        <div class="panel-header">
          <div>
            <h2>{{ selectedYear }} 年每月收入</h2>
            <p>以已收金額彙總，適合整理年度租賃所得申報資料。</p>
          </div>
          <button class="filter" type="button" @click="loadReport">重新整理</button>
        </div>

        <div class="filter-bar">
          <label class="filter-field">
            <span>屋主</span>
            <select v-model="ownerFilter">
              <option value="">全部</option>
              <option v-for="owner in ownerOptions" :key="owner.id" :value="owner.id">
                {{ owner.name }}
              </option>
            </select>
          </label>

          <label class="filter-field">
            <span>社區</span>
            <select v-model="buildingFilter">
              <option value="">全部</option>
              <option v-for="building in buildingOptions" :key="building.id" :value="building.id">
                {{ building.name }}
              </option>
            </select>
          </label>

          <button class="secondary-button" type="button" @click="clearFilters">清除篩選</button>
        </div>

        <p v-if="error" class="error-text">{{ error }}</p>
        <p v-if="loading" class="empty-text">資料載入中...</p>
        <p v-else-if="filteredReportRows.length === 0" class="empty-text">目前沒有符合條件的年度收入資料。</p>

        <div v-else class="table-wrap">
          <table class="report-table">
            <thead>
              <tr>
                <th>屋主</th>
                <th>房屋</th>
                <th v-for="month in months" :key="month" class="amount">{{ month }}月</th>
                <th class="amount">全年合計</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in filteredReportRows" :key="row.propertyId">
                <td>
                  <strong>{{ row.ownerName || '未指定屋主' }}</strong>
                  <span>{{ row.buildingName || '未指定社區' }}</span>
                </td>
                <td>
                  <strong>{{ row.unitNo || row.address }}</strong>
                  <span>{{ row.address }}</span>
                </td>
                <td v-for="month in months" :key="month" class="amount">
                  {{ row.monthlyPaid[month - 1] ? formatCurrency(row.monthlyPaid[month - 1]) : '-' }}
                </td>
                <td class="amount">
                  <strong>{{ formatCurrency(row.totalPaid) }}</strong>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section class="panel report-summary-panel">
        <div class="panel-header">
          <div>
            <h2>屋主年度小計</h2>
            <p>報稅前可先用這裡核對每位屋主總收入。</p>
          </div>
        </div>

        <div class="table-wrap">
          <table>
            <thead>
              <tr>
                <th>屋主</th>
                <th class="amount">房屋數</th>
                <th class="amount">年度收入</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="owner in ownerSummaries" :key="owner.ownerId">
                <td>{{ owner.ownerName || '未指定屋主' }}</td>
                <td class="amount">{{ owner.propertyCount }}</td>
                <td class="amount">{{ formatCurrency(owner.totalPaid) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </template>
  </AppShell>
</template>

<script setup lang="ts">
type InvoiceReportRow = {
  invoice_month: string
  amount_paid: number
  leases?: {
    properties?: {
      id?: string
      unit_no?: string
      address?: string
      owner_id?: string
      building_id?: string
      owners?: { name?: string }
      buildings?: { name?: string }
    }
  }
}

type AnnualPropertyRow = {
  propertyId: string
  ownerId: string
  ownerName: string
  buildingId: string
  buildingName: string
  unitNo: string
  address: string
  monthlyPaid: number[]
  totalPaid: number
}

const { client, isConfigured } = useSupabaseClientLite()
const { user, loadUser } = useAuth()

const selectedYear = ref(new Date().getFullYear())
const ownerFilter = ref('')
const buildingFilter = ref('')
const reportRows = ref<AnnualPropertyRow[]>([])
const loading = ref(false)
const error = ref('')
const months = Array.from({ length: 12 }, (_, index) => index + 1)

const filteredReportRows = computed(() => {
  return reportRows.value
    .filter((row) => {
      if (ownerFilter.value && row.ownerId !== ownerFilter.value) return false
      if (buildingFilter.value && row.buildingId !== buildingFilter.value) return false
      return true
    })
    .sort((a, b) => {
      const ownerCompare = a.ownerName.localeCompare(b.ownerName, 'zh-TW')
      if (ownerCompare !== 0) return ownerCompare
      return (a.unitNo || a.address).localeCompare(b.unitNo || b.address, 'zh-TW', {
        numeric: true,
        sensitivity: 'base'
      })
    })
})

const ownerOptions = computed(() => {
  const owners = new Map<string, string>()
  for (const row of reportRows.value) {
    if (row.ownerId) owners.set(row.ownerId, row.ownerName)
  }
  return [...owners.entries()]
    .map(([id, name]) => ({ id, name }))
    .sort((a, b) => a.name.localeCompare(b.name, 'zh-TW'))
})

const buildingOptions = computed(() => {
  const buildings = new Map<string, string>()
  for (const row of reportRows.value) {
    if (row.buildingId) buildings.set(row.buildingId, row.buildingName)
  }
  return [...buildings.entries()]
    .map(([id, name]) => ({ id, name }))
    .sort((a, b) => a.name.localeCompare(b.name, 'zh-TW'))
})

const summary = computed(() => {
  const rows = filteredReportRows.value
  return {
    totalPaid: rows.reduce((total, row) => total + row.totalPaid, 0),
    propertyCount: rows.length,
    ownerCount: new Set(rows.map((row) => row.ownerId || row.ownerName)).size
  }
})

const ownerSummaries = computed(() => {
  const summaries = new Map<string, { ownerId: string, ownerName: string, propertyCount: number, totalPaid: number }>()

  for (const row of filteredReportRows.value) {
    const key = row.ownerId || row.ownerName
    const current = summaries.get(key) || {
      ownerId: row.ownerId || key,
      ownerName: row.ownerName,
      propertyCount: 0,
      totalPaid: 0
    }

    current.propertyCount += 1
    current.totalPaid += row.totalPaid
    summaries.set(key, current)
  }

  return [...summaries.values()].sort((a, b) => b.totalPaid - a.totalPaid)
})

watch(selectedYear, () => {
  loadReport()
})

function clearFilters() {
  ownerFilter.value = ''
  buildingFilter.value = ''
}

async function loadReport() {
  error.value = ''

  if (!client) {
    reportRows.value = []
    return
  }

  const { data: sessionData } = await client.auth.getSession()
  if (!sessionData.session) {
    reportRows.value = []
    return
  }

  loading.value = true

  const yearStart = `${selectedYear.value}-01-01`
  const nextYearStart = `${Number(selectedYear.value) + 1}-01-01`

  const { data, error: loadError } = await client
    .from('rent_invoices')
    .select('invoice_month, amount_paid, leases(properties(id, unit_no, address, owner_id, building_id, owners(name), buildings(name)))')
    .gte('invoice_month', yearStart)
    .lt('invoice_month', nextYearStart)
    .order('invoice_month', { ascending: true })

  loading.value = false

  if (loadError) {
    error.value = loadError.message
    return
  }

  reportRows.value = buildAnnualRows((data || []) as InvoiceReportRow[])
}

function buildAnnualRows(invoices: InvoiceReportRow[]) {
  const rows = new Map<string, AnnualPropertyRow>()

  for (const invoice of invoices) {
    const property = invoice.leases?.properties
    if (!property?.id) continue

    const row = rows.get(property.id) || {
      propertyId: property.id,
      ownerId: property.owner_id || '',
      ownerName: property.owners?.name || '',
      buildingId: property.building_id || '',
      buildingName: property.buildings?.name || '',
      unitNo: property.unit_no || '',
      address: property.address || '',
      monthlyPaid: Array(12).fill(0),
      totalPaid: 0
    }

    const monthIndex = new Date(invoice.invoice_month).getMonth()
    const amountPaid = Number(invoice.amount_paid || 0)
    row.monthlyPaid[monthIndex] += amountPaid
    row.totalPaid += amountPaid
    rows.set(property.id, row)
  }

  return [...rows.values()]
}

function exportCsv() {
  const headers = [
    '年度',
    '屋主',
    '社區',
    '房號',
    '地址',
    ...months.map((month) => `${month}月收入`),
    '全年合計'
  ]

  const rows = filteredReportRows.value.map((row) => [
    String(selectedYear.value),
    row.ownerName || '未指定屋主',
    row.buildingName || '未指定社區',
    row.unitNo,
    row.address,
    ...row.monthlyPaid.map(String),
    String(row.totalPaid)
  ])

  const summaryRows = [
    [],
    ['屋主年度小計'],
    ['年度', '屋主', '房屋數', '年度收入'],
    ...ownerSummaries.value.map((owner) => [
      String(selectedYear.value),
      owner.ownerName || '未指定屋主',
      String(owner.propertyCount),
      String(owner.totalPaid)
    ])
  ]

  const csv = [headers, ...rows, ...summaryRows]
    .map((row) => row.map(escapeCsvCell).join(','))
    .join('\r\n')

  downloadCsv(`租金收入報表-${selectedYear.value}.csv`, csv)
}

function escapeCsvCell(value: string | number | null | undefined) {
  const text = String(value ?? '')
  return `"${text.replaceAll('"', '""')}"`
}

function downloadCsv(filename: string, csv: string) {
  const blob = new Blob([`\uFEFF${csv}`], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  URL.revokeObjectURL(url)
}

onMounted(async () => {
  await loadUser()
  await loadReport()
})
</script>
