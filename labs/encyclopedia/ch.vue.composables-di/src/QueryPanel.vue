<script setup lang="ts">
import type { WorkOrderStatus } from './contracts'
import { requireRepository } from './injection'
import { useWorkOrderQuery } from './useWorkOrderQuery'

defineProps<{ panelId: string }>()

// Data source: the injected port is shared; invocation-local query state is not.
const { status, orders, loading, setStatus } = useWorkOrderQuery(requireRepository())

function updateStatus(event: Event) {
  // Mapping: only values emitted by the closed status select become WorkOrderStatus.
  setStatus((event.target as HTMLSelectElement).value as WorkOrderStatus)
}
</script>

<template>
  <section :data-panel-id="panelId">
    <h2>面板 {{ panelId }}</h2>
    <label>状态<select :value="status" @change="updateStatus"><option value="CREATED">已创建</option><option value="IN_PROGRESS">处理中</option><option value="COMPLETED">已完成</option></select></label>
    <p v-if="loading" role="status">查询中</p>
    <ul v-else><li v-for="order in orders" :key="order.id">{{ order.id }} {{ order.title }}</li></ul>
  </section>
</template>

