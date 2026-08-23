<script setup lang="ts">
import { RouterLink } from 'vue-router'
import type { WorkOrderStatusFilter } from '../navigation-contracts'

// Data source: router props map the validated URL query into this page contract.
defineProps<{ status: WorkOrderStatusFilter }>()

const orders = [
  { id: 'WO-3001', title: '主轴振动复核' },
  { id: 'WO-3002', title: '润滑站油位检查' },
]
</script>

<template>
  <article>
    <h1 tabindex="-1" data-page-title>工单列表</h1>
    <p data-testid="status-filter">URL 筛选：{{ status }}</p>
    <ul>
      <li v-for="order in orders" :key="order.id">
        <!-- Mapping: named location delegates encoding and path construction to the router. -->
        <RouterLink :to="{ name: 'work-order-detail', params: { workOrderId: order.id }, query: { from: 'list' } }">
          {{ order.id }} · {{ order.title }}
        </RouterLink>
      </li>
    </ul>
  </article>
</template>

