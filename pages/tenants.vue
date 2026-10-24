<template>
  <ManagementPage
    title="租客管理"
    subtitle="管理租客聯絡資訊、轉帳帳戶後五碼與緊急聯絡資料。"
    list-title="租客列表"
    action-label="新增租客"
    table="tenants"
    select="*, leases(status, monthly_rent, properties(unit_no, address, building_id, owner_id, buildings(name), owners(name)))"
    :fields="fields"
    :columns="columns"
    :filters="filters"
  />
</template>

<script setup lang="ts">
import type { FormField, TableColumn, TableFilter } from '~/types/management'

const { owners, buildings } = useReferenceOptions()

const fields: FormField[] = [
  { key: 'name', label: '租客姓名', required: true },
  { key: 'phone', label: '電話', type: 'tel' },
  { key: 'email', label: 'Email', type: 'email' },
  { key: 'line_id', label: 'LINE ID' },
  {
    key: 'bank_account_last5',
    label: '轉帳帳戶後五碼',
    required: true,
    placeholder: '例如：12345',
    helpText: '只需記錄帳戶最後 5 碼，供收到轉帳後快速查找租客。',
    inputmode: 'numeric',
    minlength: 5,
    maxlength: 5,
    pattern: '[0-9]{5}'
  },
  { key: 'identity_no', label: '身分證字號' },
  { key: 'emergency_contact', label: '緊急聯絡人' },
  { key: 'notes', label: '備註', type: 'textarea' }
]

const columns: TableColumn[] = [
  { key: 'name', label: '租客' },
  { key: 'leases', label: '承租房屋', format: (row) => activeLeaseProperty(row) },
  { key: 'leases', label: '月租金', align: 'right', format: (row) => activeLeaseRent(row) },
  { key: 'phone', label: '電話' },
  { key: 'bank_account_last5', label: '帳戶後五碼', format: (row) => row.bank_account_last5 || '未登記' },
  { key: 'line_id', label: 'LINE' },
  { key: 'emergency_contact', label: '緊急聯絡人' }
]

const filters = computed<TableFilter[]>(() => [
  { key: 'leases.properties.owner_id', label: '屋主', options: owners.value },
  { key: 'leases.properties.building_id', label: '社區', options: buildings.value }
])

function activeLease(row: Record<string, any>) {
  return (row.leases || []).find((lease: any) => lease.status === 'active') || row.leases?.[0]
}

function activeLeaseProperty(row: Record<string, any>) {
  const lease = activeLease(row)
  const property = lease?.properties
  if (!property) return '尚未綁定房屋'

  const unit = property.unit_no || property.address
  const building = property.buildings?.name
  return [unit, building].filter(Boolean).join(' / ')
}

function activeLeaseRent(row: Record<string, any>) {
  const lease = activeLease(row)
  return lease ? formatCurrency(lease.monthly_rent) : '-'
}
</script>
