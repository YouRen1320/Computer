<script setup lang="ts">
import { createWorkOrderStats, type WorkOrder } from './work-order-stats'

// Data source: fixed records let the cache and DOM transition table be reproduced exactly.
const initialOrders: WorkOrder[] = [
  { id: 'WO-1', title: '主轴过热', status: 'CREATED', priority: 'HIGH' },
  { id: 'WO-2', title: '更换滤芯', status: 'RESOLVED', priority: 'LOW' },
]

const {
  openCount,
  visibleOrders,
  addOrder,
  setStatusFilter,
} = createWorkOrderStats(initialOrders)

function addOpenOrder() {
  // Side effect: the UI command changes one owned source; computed values remain read-only.
  addOrder({ id: 'WO-3', title: '检查电机异响', status: 'IN_PROGRESS', priority: 'CRITICAL' })
}
</script>

<template>
  <section aria-labelledby="stats-title">
    <h2 id="stats-title">工单派生统计</h2>
    <p data-testid="open-count">开放：{{ openCount }}</p>
    <p data-testid="visible-count">当前列表：{{ visibleOrders.length }}</p>
    <button type="button" @click="addOpenOrder">加入开放工单</button>
    <button type="button" @click="setStatusFilter('RESOLVED')">只看已完成</button>
    <ul>
      <li v-for="order in visibleOrders" :key="order.id">{{ order.title }}</li>
    </ul>
  </section>
</template>

