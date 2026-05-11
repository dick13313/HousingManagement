<template>
  <ManagementPage
    title="付款紀錄"
    eyebrow="租務管理"
    subtitle="登錄租客實際付款紀錄，保留付款日期、金額與方式。"
    list-title="付款列表"
    action-label="登錄付款"
    table="payments"
    select="*, rent_invoices(invoice_month, leases(tenants(name), properties(address)))"
    :fields="fields"
    :columns="columns"
  />
</template>

<script setup lang="ts">
import type { FormField, TableColumn } from '~/types/management'

const { invoices } = useReferenceOptions()

const fields = computed<FormField[]>(() => [
  { key: 'rent_invoice_id', label: '租金帳款', type: 'select', required: true, options: invoices.value },
  { key: 'paid_on', label: '付款日期', type: 'date', required: true },
  { key: 'amount', label: '付款金額', type: 'number', valueType: 'number', required: true },
  {
    key: 'method',
    label: '付款方式',
    type: 'select',
    required: true,
    options: [
      { label: '現金', value: 'cash' },
      { label: '轉帳', value: 'bank_transfer' },
      { label: '支票', value: 'check' },
      { label: '其他', value: 'other' }
    ]
  },
  { key: 'receipt_no', label: '收據編號' },
  { key: 'notes', label: '備註', type: 'textarea' }
])

const columns: TableColumn[] = [
  { key: 'rent_invoices.leases.tenants.name', label: '租客' },
  { key: 'rent_invoices.leases.properties.address', label: '房屋' },
  { key: 'rent_invoices.invoice_month', label: '月份' },
  { key: 'paid_on', label: '付款日' },
  { key: 'amount', label: '金額', align: 'right', format: (row) => formatCurrency(row.amount) },
  { key: 'method', label: '方式', format: (row) => statusLabel(row.method) }
]
</script>
