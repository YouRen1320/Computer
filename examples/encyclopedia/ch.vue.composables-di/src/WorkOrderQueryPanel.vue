<script setup lang="ts">
import type { WorkOrderStatus } from './contracts'
import { requireWorkOrderRepository } from './injection'
import { useWorkOrderQuery } from './useWorkOrderQuery'

const props = withDefaults(defineProps<{
  panelId: string
  initialStatus?: WorkOrderStatus
}>(), { initialStatus: 'CREATED' })

// Data source: the repository crosses layout depth through DI; query state remains per panel instance.
const repository = requireWorkOrderRepository()
const { status, orders, loading, error, setStatus, reload } = useWorkOrderQuery(repository, props.initialStatus)

function onStatusChange(event: Event) {
  // Non-obvious mapping: the closed select option set is mapped back to the domain union.
  setStatus((event.target as HTMLSelectElement).value as WorkOrderStatus)
}
</script>

<template>
  <section :data-panel-id="panelId" :aria-labelledby="`${panelId}-title`">
    <h2 :id="`${panelId}-title`">查询面板 {{ panelId }}</h2>
    <label>
      工单状态
      <select :value="status" data-testid="status" @change="onStatusChange">
        <option value="CREATED">已创建</option>
        <option value="IN_PROGRESS">处理中</option>
        <option value="COMPLETED">已完成</option>
      </select>
    </label>
    <button type="button" data-testid="reload" :disabled="loading" @click="reload">重新查询</button>
    <p v-if="loading" role="status">查询中</p>
    <p v-else-if="error" role="alert">{{ error.message }}</p>
    <ul v-else data-testid="orders">
      <li v-for="order in orders" :key="order.id">{{ order.id }} · {{ order.title }}</li>
    </ul>
  </section>
</template>
