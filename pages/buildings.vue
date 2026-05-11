<template>
  <ManagementPage
    title="大樓社區"
    subtitle="管理房屋所在的大樓、社區或集合住宅。"
    list-title="社區列表"
    action-label="新增社區"
    table="buildings"
    :fields="fields"
    :columns="columns"
  />
</template>

<script setup lang="ts">
import type { FormField, TableColumn } from '~/types/management'

const fields: FormField[] = [
  { key: 'name', label: '社區名稱', required: true },
  { key: 'address', label: '地址' },
  { key: 'manager_name', label: '管理單位' },
  { key: 'notes', label: '備註', type: 'textarea' }
]

const columns: TableColumn[] = [
  { key: 'name', label: '社區' },
  { key: 'address', label: '地址' },
  { key: 'manager_name', label: '管理單位' }
]
</script>
