<template>
  <span class="status" :class="tone">
    {{ statusLabel(value) }}
  </span>
</template>

<script setup lang="ts">
defineProps<{
  value: string
  tone?: string
}>()
</script>
