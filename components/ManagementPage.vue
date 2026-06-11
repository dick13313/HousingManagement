<template>
  <AppShell>
    <section class="page-heading">
      <div>
        <p class="eyebrow">{{ eyebrow }}</p>
        <h1>{{ title }}</h1>
      </div>
      <button class="primary-button sticky-page-action" type="button" @click="openCreateForm">
        {{ actionLabel }}
      </button>
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

    <section class="panel">
      <div class="panel-header">
        <div>
          <h2>{{ listTitle }}</h2>
          <p>{{ subtitle }}</p>
          <p class="list-meta">{{ listMeta }}</p>
        </div>
        <button class="filter" type="button" @click="load">重新整理</button>
      </div>

      <div v-if="filters.length" class="filter-bar">
        <label v-for="filter in filters" :key="filter.key" class="filter-field">
          <span>{{ filter.label }}</span>
          <select v-model="selectedFilters[filter.key]">
            <option value="">全部</option>
            <option v-for="option in filter.options" :key="option.value" :value="option.value">
              {{ option.label }}
            </option>
          </select>
        </label>
        <button class="secondary-button" type="button" @click="clearFilters">清除篩選</button>
      </div>

      <p v-if="filters.length" class="filter-summary" aria-live="polite">
        {{ filtersDirty ? `目前套用 ${activeFilterCount} 個篩選條件，顯示 ${filteredRows.length} 筆資料。` : '尚未套用篩選條件，目前顯示全部資料。' }}
      </p>

      <section v-if="error" class="state-panel error-panel" aria-live="polite">
        <strong>資料暫時無法顯示</strong>
        <p>{{ error }}</p>
        <button class="secondary-button" type="button" @click="load">重新整理</button>
      </section>

      <section v-else-if="loading" class="state-panel" aria-live="polite">
        <strong>資料載入中</strong>
        <p>系統正在同步最新資料，通常只需要幾秒鐘。</p>
      </section>

      <section v-else-if="filteredRows.length === 0" class="state-panel" aria-live="polite">
        <strong>目前沒有符合條件的資料</strong>
        <p>{{ filtersDirty ? '先清除篩選條件，或直接新增一筆資料。' : '可以先新增第一筆資料，之後就能在這裡持續管理。' }}</p>
        <div class="state-actions">
          <button v-if="filtersDirty" class="secondary-button" type="button" @click="clearFilters">清除篩選</button>
          <button class="primary-button" type="button" @click="openCreateForm">{{ actionLabel }}</button>
        </div>
      </section>

      <template v-else>
        <div class="mobile-card-list" aria-label="手機資料卡片">
          <article v-for="row in filteredRows" :key="`${row.id}-card`" class="mobile-data-card">
            <div class="mobile-data-card__header">
              <div>
                <strong>{{ mobilePrimaryValue(row) }}</strong>
                <p>{{ mobileSecondaryValue(row) }}</p>
              </div>
              <StatusPill
                v-if="statusColumn"
                :value="String(getColumnValue(row, statusColumn))"
                :tone="getStatusTone(String(getColumnValue(row, statusColumn)))"
              />
            </div>

            <dl class="mobile-data-card__details">
              <div v-for="column in mobileDetailColumns" :key="column.key">
                <dt>{{ column.label }}</dt>
                <dd>{{ getColumnValue(row, column) }}</dd>
              </div>
            </dl>

            <div class="row-actions mobile-row-actions">
              <button class="text-button inline-action" type="button" :disabled="saving" @click="editRow(row)">
                編輯
              </button>
              <button class="danger-button" type="button" :disabled="saving" @click="deleteRow(row)">
                移除
              </button>
            </div>
          </article>
        </div>

        <div class="table-wrap desktop-table-wrap">
          <table>
            <thead>
              <tr>
                <th v-for="column in columns" :key="column.key" :class="{ amount: column.align === 'right' }">
                  {{ column.label }}
                </th>
                <th>操作</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in filteredRows" :key="row.id">
                <td
                  v-for="column in columns"
                  :key="column.key"
                  :class="{ amount: column.align === 'right' }"
                >
                  <StatusPill
                    v-if="column.status"
                    :value="String(getColumnValue(row, column))"
                    :tone="getStatusTone(String(getColumnValue(row, column)))"
                  />
                  <span v-else>{{ getColumnValue(row, column) }}</span>
                </td>
                <td>
                  <div class="row-actions">
                    <button class="text-button inline-action" type="button" :disabled="saving" @click="editRow(row)">
                      編輯
                    </button>
                    <button class="danger-button" type="button" :disabled="saving" @click="deleteRow(row)">
                      移除
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
      <div v-if="showForm" class="modal-backdrop" @click.self="closeForm">
        <section class="modal-panel" role="dialog" aria-modal="true" :aria-label="editingId ? '編輯資料' : actionLabel">
          <div class="panel-header compact">
            <div>
              <h2>{{ editingId ? '編輯資料' : actionLabel }}</h2>
              <p>{{ editingId ? '修改資料後儲存更新。' : '填寫必要資料後儲存到 Supabase。' }}</p>
            </div>
            <button class="icon-button" type="button" aria-label="關閉表單" @click="closeForm">×</button>
          </div>

          <div class="form-helper-panel" aria-live="polite">
            <strong>{{ editingId ? '編輯模式' : '新增模式' }}</strong>
            <span>標示 <em>*</em> 的欄位為必填，建議先完成必要欄位再補充備註。</span>
          </div>

          <form class="entity-form modal-form" @submit.prevent="submit">
            <label v-for="field in fields" :key="field.key" class="form-field">
              <span>
                {{ field.label }}
                <em v-if="field.required" class="required-mark" aria-hidden="true">*</em>
              </span>
              <small v-if="field.helpText" class="field-help">{{ field.helpText }}</small>

              <textarea
                v-if="field.type === 'textarea'"
                v-model="form[field.key]"
                :required="field.required"
                :placeholder="field.placeholder"
              />

              <select
                v-else-if="field.type === 'select'"
                v-model="form[field.key]"
                :required="field.required"
              >
                <option value="">請選擇</option>
                <option v-for="option in field.options || []" :key="option.value" :value="option.value">
                  {{ option.label }}
                </option>
              </select>

              <input
                v-else
                v-model="form[field.key]"
                :type="field.type || 'text'"
                :required="field.required"
                :placeholder="field.placeholder"
                :autocomplete="field.autocomplete || defaultAutocomplete(field)"
                :inputmode="field.inputmode || defaultInputMode(field)"
              />
            </label>

            <div class="form-actions sticky-form-actions">
              <button class="primary-button" type="submit" :disabled="saving">
                {{ saving ? '儲存中' : editingId ? '儲存修改' : '儲存' }}
              </button>
              <button class="secondary-button" type="button" @click="closeForm">取消</button>
            </div>
          </form>
        </section>
      </div>
    </Teleport>
  </AppShell>
</template>

<script setup lang="ts">
import type { FormField, TableColumn, TableFilter } from '~/types/management'

const props = withDefaults(
  defineProps<{
    title: string
    eyebrow?: string
    subtitle: string
    listTitle: string
    actionLabel: string
    table: string
    select?: string
    order?: string
    fields: FormField[]
    columns: TableColumn[]
    filters?: TableFilter[]
  }>(),
  {
    eyebrow: '資料管理',
    select: '*',
    order: 'created_at',
    filters: () => []
  }
)

const showForm = ref(false)
const editingId = ref('')
const form = reactive<Record<string, any>>({})
const selectedFilters = reactive<Record<string, string>>({})
const { user, loadUser } = useAuth()

const { rows, loading, saving, error, isConfigured, load, create, update, remove } = useSupabaseTable(props.table, {
  select: props.select,
  order: props.order,
  ascending: false
})

const filteredRows = computed(() => {
  return rows.value.filter((row) => {
    return props.filters.every((filter) => {
      const selected = selectedFilters[filter.key]
      if (!selected) return true
      return getPathValues(row, filter.key).map(String).includes(selected)
    })
  })
})

const filtersDirty = computed(() => {
  return props.filters.some((filter) => Boolean(selectedFilters[filter.key]))
})

const activeFilterCount = computed(() => {
  return props.filters.filter((filter) => Boolean(selectedFilters[filter.key])).length
})

const listMeta = computed(() => {
  if (loading.value) return '資料同步中...'
  if (!rows.value.length) return '尚未建立資料'
  if (filtersDirty.value) return `已篩選出 ${filteredRows.value.length} / ${rows.value.length} 筆資料`
  return `共 ${rows.value.length} 筆資料`
})

const statusColumn = computed(() => {
  return props.columns.find((column) => column.status) || null
})

const mobileColumns = computed(() => {
  return props.columns.filter((column) => !column.status)
})

const mobileDetailColumns = computed(() => {
  return mobileColumns.value.slice(2)
})

function resetForm() {
  editingId.value = ''
  for (const field of props.fields) {
    form[field.key] = ''
  }
}

function openCreateForm() {
  resetForm()
  showForm.value = true
}

function closeForm() {
  resetForm()
  showForm.value = false
}

function clearFilters() {
  for (const filter of props.filters) {
    selectedFilters[filter.key] = ''
  }
}

function editRow(row: Record<string, any>) {
  editingId.value = row.id
  for (const field of props.fields) {
    form[field.key] = row[field.key] ?? ''
  }
  showForm.value = true
}

async function deleteRow(row: Record<string, any>) {
  const label = getDeleteLabel(row)
  const ok = window.confirm(`確定要移除「${label}」嗎？相關的租約、帳款、付款與提醒紀錄也可能一起移除，此操作無法復原。`)
  if (!ok) return

  await remove(row.id)
}

function getDeleteLabel(row: Record<string, any>) {
  return row.name || row.address || row.invoice_month || row.paid_on || row.created_at || row.id
}

async function submit() {
  const payload: Record<string, any> = {}

  for (const field of props.fields) {
    const value = form[field.key]
    payload[field.key] = field.valueType === 'number' && value !== '' ? Number(value) : value
  }

  const ok = editingId.value
    ? await update(editingId.value, payload)
    : await create(payload)

  if (ok) {
    closeForm()
  }
}

function getColumnValue(row: Record<string, any>, column: TableColumn) {
  if (column.format) return column.format(row)
  return column.key.split('.').reduce((value, key) => value?.[key], row) ?? '-'
}

function mobilePrimaryValue(row: Record<string, any>) {
  const column = mobileColumns.value[0]
  return column ? getColumnValue(row, column) : row.id
}

function mobileSecondaryValue(row: Record<string, any>) {
  const column = mobileColumns.value[1]
  if (!column) return '可開啟後查看完整資料'
  return `${column.label}：${getColumnValue(row, column)}`
}

function defaultAutocomplete(field: FormField) {
  if (field.type === 'email') return 'email'
  if (field.type === 'tel') return 'tel'
  return 'off'
}

function defaultInputMode(field: FormField) {
  if (field.type === 'email') return 'email'
  if (field.type === 'tel') return 'tel'
  if (field.type === 'number') return 'decimal'
  return 'text'
}

function getPathValues(row: Record<string, any>, path: string) {
  const keys = path.split('.')

  function walk(value: any, index: number): any[] {
    if (value == null) return []
    if (index >= keys.length) return Array.isArray(value) ? value : [value]
    if (Array.isArray(value)) return value.flatMap((item) => walk(item, index))
    return walk(value[keys[index]], index + 1)
  }

  return walk(row, 0).filter((value) => value != null && value !== '')
}

onMounted(async () => {
  resetForm()
  clearFilters()
  await loadUser()
})
</script>
