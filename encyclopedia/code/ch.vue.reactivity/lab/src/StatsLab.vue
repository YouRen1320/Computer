<script setup lang="ts">
import { createStatsModel, type WorkOrder } from './stats-model'

// Data source: fixed records define the component's observable transition table.
const seed: WorkOrder[] = [
  { id: 'WO-1', title: '主轴过热', status: 'CREATED', priority: 'HIGH' },
  { id: 'WO-2', title: '滤芯更换', status: 'RESOLVED', priority: 'LOW' },
  { id: 'WO-3', title: '电机异响', status: 'IN_PROGRESS', priority: 'CRITICAL' },
]

const {
  openCount,
  criticalCount,
  visibleOrders,
  addOrder,
  completeOrder,
  setFilter,
} = createStatsModel(seed)

function addDeterministicOrder() {
  // Side effect: a stable ID and status make the post-click DOM oracle deterministic.
  addOrder({ id: 'WO-4', title: '润滑油不足', status: 'CREATED', priority: 'MEDIUM' })
}
</script>

<template>
  <section aria-labelledby="lab-title">
    <h2 id="lab-title">来源与派生状态</h2>
    <p data-testid="open">开放：{{ openCount }}</p>
    <p data-testid="critical">严重：{{ criticalCount }}</p>
    <p data-testid="visible">可见：{{ visibleOrders.length }}</p>

    <button data-testid="add" type="button" @click="addDeterministicOrder">添加开放工单</button>
    <button data-testid="complete" type="button" @click="completeOrder('WO-1')">完成 WO-1</button>
    <button data-testid="filter" type="button" @click="setFilter('RESOLVED')">只看已完成</button>

    <ul>
      <li v-for="order in visibleOrders" :key="order.id">{{ order.id }} {{ order.title }}</li>
    </ul>
  </section>
</template>

