<script setup lang="ts">
import { ref, watch } from 'vue'
import type { Filter, Order } from '../src/resource-loader'

const fixtures: Record<Filter, Order[]> = {
  ALL: [
    { id: 'WO-1', title: '主轴过热', status: 'CREATED' },
    { id: 'WO-2', title: '滤芯更换', status: 'COMPLETED' },
  ],
  CREATED: [{ id: 'WO-1', title: '主轴过热', status: 'CREATED' }],
  COMPLETED: [{ id: 'WO-2', title: '滤芯更换', status: 'COMPLETED' }],
}
const latency: Record<Filter, number> = { ALL: 40, CREATED: 10, COMPLETED: 25 }

// Data source: this fault still uses one filter, but it fails to retire previous runs.
const filter = ref<Filter>('ALL')
const orders = ref<Order[]>([])
const trace: string[] = []
let active = 0

watch(filter, (next) => {
  trace.push(`start:${next}`)
  active += 1
  // Injected side effect: no cleanup exists, so every stale timer remains able to commit.
  setTimeout(() => {
    active -= 1
    orders.value = fixtures[next].map(order => ({ ...order }))
    trace.push(`commit:${next}`)
  }, latency[next])
}, { immediate: true })

// Responsibility: expose the fault's state and trace for first-divergence diagnosis.
defineExpose({ getTrace: () => [...trace], activeResources: () => active })
</script>

<template>
  <section>
    <label for="fault-filter">故障筛选</label>
    <select id="fault-filter" v-model="filter">
      <option value="ALL">全部</option>
      <option value="CREATED">已创建</option>
      <option value="COMPLETED">已完成</option>
    </select>
    <p data-testid="fault-result">{{ orders.map(order => order.id).join(',') }}</p>
  </section>
</template>
