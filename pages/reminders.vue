<template>
  <ManagementPage
    title="提醒管理"
    eyebrow="租務管理"
    subtitle="管理未繳房租提醒紀錄，之後可擴充 Email、LINE 或簡訊。"
    list-title="提醒紀錄"
    action-label="新增提醒"
    table="reminders"
    select="*, rent_invoices(invoice_month, amount_due), tenants(name, phone)"
    :fields="fields"
    :columns="columns"
  />
</template>

<script setup lang="ts">
import type { FormField, TableColumn } from '~/types/management'

const { invoices, tenants } = useReferenceOptions()

const fields = computed<FormField[]>(() => [
  { key: 'rent_invoice_id', label: '租金帳款', type: 'select', required: true, options: invoices.value },
  { key: 'tenant_id', label: '租客', type: 'select', required: true, options: tenants.value },
  {
    key: 'channel',
    label: '提醒方式',
    type: 'select',
    required: true,
    options: [
      { label: '系統內', value: 'in_app' },
      { label: 'Email', value: 'email' },
      { label: 'LINE', value: 'line' },
      { label: '簡訊', value: 'sms' }
    ]
  },
  {
    key: 'status',
    label: '發送狀態',
    type: 'select',
    required: true,
    options: [
      { label: '待發送', value: 'pending' },
      { label: '已發送', value: 'sent' },
      { label: '失敗', value: 'failed' }
    ]
  },
  { key: 'notes', label: '備註', type: 'textarea' }
])

const columns: TableColumn[] = [
  { key: 'tenants.name', label: '租客' },
  { key: 'rent_invoices.invoice_month', label: '月份' },
  { key: 'rent_invoices.amount_due', label: '金額', align: 'right', format: (row) => formatCurrency(row.rent_invoices?.amount_due) },
  { key: 'channel', label: '方式', format: (row) => statusLabel(row.channel) },
  { key: 'status', label: '狀態', status: true },
  { key: 'created_at', label: '建立時間', format: (row) => formatDate(row.created_at) }
]
</script>
