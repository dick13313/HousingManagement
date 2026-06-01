<template>
  <ManagementPage
    title="租約管理"
    subtitle="建立租客與房屋之間的租賃關係，保留調租與換房歷史。"
    list-title="租約列表"
    action-label="新增租約"
    table="leases"
    select="*, tenants(name), properties(address, unit_no, owner_id, building_id, owners(name), buildings(name))"
    :fields="fields"
    :columns="columns"
    :filters="filters"
  />
</template>

<script setup lang="ts">
import type { FormField, TableColumn, TableFilter } from '~/types/management'

const { tenants, properties, owners, buildings } = useReferenceOptions()

const fields = computed<FormField[]>(() => [
  { key: 'tenant_id', label: '租客', type: 'select', required: true, options: tenants.value },
  { key: 'property_id', label: '房屋', type: 'select', required: true, options: properties.value },
  { key: 'starts_on', label: '起租日', type: 'date', required: true },
  { key: 'ends_on', label: '結束日', type: 'date', required: true },
  { key: 'monthly_rent', label: '月租金', type: 'number', valueType: 'number', required: true },
  { key: 'deposit', label: '押金', type: 'number', valueType: 'number' },
  { key: 'rent_due_day', label: '每月繳租日', type: 'number', valueType: 'number', required: true },
  {
    key: 'payment_cycle_months',
    label: '預設繳租週期',
    type: 'select',
    valueType: 'number',
    required: true,
    options: [
      { label: '月繳', value: '1' },
      { label: '季繳', value: '3' },
      { label: '半年繳', value: '6' },
      { label: '年繳', value: '12' }
    ]
  },
  {
    key: 'status',
    label: '狀態',
    type: 'select',
    required: true,
    options: [
      { label: '生效中', value: 'active' },
      { label: '即將到期', value: 'ending_soon' },
      { label: '已結束', value: 'ended' }
    ]
  },
  { key: 'notes', label: '備註', type: 'textarea' }
])

const columns: TableColumn[] = [
  { key: 'tenants.name', label: '租客' },
  { key: 'properties.unit_no', label: '房號' },
  { key: 'properties.buildings.name', label: '社區' },
  { key: 'properties.owners.name', label: '屋主' },
  { key: 'monthly_rent', label: '月租金', align: 'right', format: (row) => formatCurrency(row.monthly_rent) },
  { key: 'payment_cycle_months', label: '繳租週期', format: (row) => formatPaymentCycle(row.payment_cycle_months) },
  { key: 'starts_on', label: '起租日' },
  { key: 'ends_on', label: '到期日' },
  { key: 'status', label: '狀態', status: true }
]

const filters = computed<TableFilter[]>(() => [
  { key: 'properties.owner_id', label: '屋主', options: owners.value },
  { key: 'properties.building_id', label: '社區', options: buildings.value }
])

function formatPaymentCycle(months: number) {
  if (months === 1) return '月繳'
  if (months === 3) return '季繳'
  if (months === 6) return '半年繳'
  if (months === 12) return '年繳'
  return `${months || 1} 個月`
}
</script>
