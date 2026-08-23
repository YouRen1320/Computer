<script setup lang="ts">
defineProps<{ gateway: { list(): Promise<readonly { id: string; title: string; status: string }[]> } }>()
// Responsibility: mirror the exercise's public surface without exposing implementation state.
defineEmits<{ select: [payload: { workOrderId: string }] }>()
</script>

<template>
  <section><p role="status">正在查询</p><ul aria-label="工单结果"><li><button type="button" @click="$emit('select', { workOrderId: 'WO-9001' })">打开工单 WO-9001</button></li></ul></section>
</template>
