<template>
  <ManagementPage
    title="房屋管理"
    subtitle="管理每間房屋的屋主、社區、地址與出租狀態。"
    list-title="房屋列表"
    action-label="新增房屋"
    table="properties"
    select="*, owners(name), buildings(name), leases(status, monthly_rent, tenants(name))"
    :fields="fields"
    :columns="columns"
    :filters="filters"
  />
</template>

<script setup lang="ts">
import type { FormField, TableColumn, TableFilter } from '~/types/management'

const { owners, buildings } = useReferenceOptions()

const fields = computed<FormField[]>(() => [
  { key: 'owner_id', label: '屋主', type: 'select', required: true, options: owners.value },
  { key: 'building_id', label: '大樓社區', type: 'select', options: buildings.value },
  { key: 'address', label: '地址', required: true },
  { key: 'floor', label: '樓層' },
  { key: 'unit_no', label: '房號' },
  { key: 'layout', label: '房型' },
  { key: 'area_ping', label: '坪數', type: 'number', valueType: 'number' },
  {
    key: 'status',
    label: '狀態',
    type: 'select',
    required: true,
    options: [
      { label: '空屋', value: 'vacant' },
      { label: '出租中', value: 'rented' },
      { label: '停用', value: 'disabled' }
    ]
  },
  { key: 'notes', label: '備註', type: 'textarea' }
])

const columns: TableColumn[] = [
  { key: 'address', label: '房屋' },
  { key: 'leases', label: '目前租客', format: (row) => activeLeaseTenant(row) },
  { key: 'leases', label: '月租金', align: 'right', format: (row) => activeLeaseRent(row) },
  { key: 'owners.name', label: '屋主' },
  { key: 'buildings.name', label: '社區' },
  { key: 'unit_no', label: '房號' },
  { key: 'status', label: '狀態', status: true }
]

const filters = computed<TableFilter[]>(() => [
  { key: 'owner_id', label: '屋主', options: owners.value },
  { key: 'building_id', label: '社區', options: buildings.value }
])

function activeLease(row: Record<string, any>) {
  return (row.leases || []).find((lease: any) => lease.status === 'active') || row.leases?.[0]
}

function activeLeaseTenant(row: Record<string, any>) {
  return activeLease(row)?.tenants?.name || '尚未出租'
}

function activeLeaseRent(row: Record<string, any>) {
  const lease = activeLease(row)
  return lease ? formatCurrency(lease.monthly_rent) : '-'
}
</script>
