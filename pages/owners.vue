<template>
  <ManagementPage
    title="屋主管理"
    subtitle="管理房屋所有權人與聯絡資訊。"
    list-title="屋主列表"
    action-label="新增屋主"
    table="owners"
    :fields="fields"
    :columns="columns"
  />
</template>

<script setup lang="ts">
import type { FormField, TableColumn } from '~/types/management'

const fields: FormField[] = [
  { key: 'name', label: '屋主姓名', required: true },
  { key: 'phone', label: '電話', type: 'tel' },
  { key: 'email', label: 'Email', type: 'email' },
  { key: 'address', label: '地址' },
  { key: 'notes', label: '備註', type: 'textarea' }
]

const columns: TableColumn[] = [
  { key: 'name', label: '屋主' },
  { key: 'phone', label: '電話' },
  { key: 'email', label: 'Email' },
  { key: 'address', label: '地址' }
]
</script>
