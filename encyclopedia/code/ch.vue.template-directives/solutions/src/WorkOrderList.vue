<script setup lang="ts">
interface WorkOrderItem {
  id: string
  number: string
  status: 'CREATED' | 'IN_PROGRESS'
}

// 固定夹具与公开练习一致，确保红绿差异只来自 key 身份表达式。
const orders: WorkOrderItem[] = [
  { id: 'wo-a', number: 'WO-2026-201', status: 'CREATED' },
  { id: 'wo-b', number: 'WO-2026-202', status: 'IN_PROGRESS' },
]

function selectOrder(id: string): void {
  // 本地选择只留下可观察事件，不执行任何 FactoryCare 状态迁移。
  console.info(`selected=${id}`)
}
</script>

<template>
  <section aria-labelledby="orders-title">
    <h1 id="orders-title">FactoryCare 工单</h1>
    <p v-if="orders.length === 0">暂无工单。</p>
    <ul v-else aria-label="工单列表">
      <li v-for="order in orders" :key="order.id" :data-order-id="order.id">
        <span>{{ order.number }}</span>
        <button
          type="button"
          :aria-label="`选择工单 ${order.number}`"
          @click="selectOrder(order.id)"
        >选择</button>
      </li>
    </ul>
  </section>
</template>

<style scoped>
button { min-block-size: 44px; }
button:focus-visible { outline: 3px solid #185c9d; outline-offset: 2px; }
</style>
