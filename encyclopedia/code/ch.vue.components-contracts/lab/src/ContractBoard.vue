<script setup lang="ts">
import { computed, ref } from 'vue'
import FilterBar from './FilterBar.vue'
import OrderCard from './OrderCard.vue'
import StatusEditor from './StatusEditor.vue'
import { ordersFixture, type Filter, type Status, type WorkOrder } from './contracts'

// Data source: all mutable business views live in this parent component.
const orders = ref<WorkOrder[]>(ordersFixture.map(order => ({ ...order })))
const filter = ref<Filter>('ALL')
const selectedId = ref<string | null>(null)
const eventTrace = ref<Array<{ name: string; payload: unknown }>>([])

const visibleOrders = computed(() => orders.value.filter(order =>
  filter.value === 'ALL' ? true : order.status === filter.value,
))

function handleSelect(payload: { orderId: string }) {
  // Side effect: parent records the exact event before updating its owned selection source.
  eventTrace.value.push({ name: 'select', payload: { ...payload } })
  selectedId.value = payload.orderId
}

function handleStatus(orderId: string, next: Status) {
  eventTrace.value.push({ name: 'update:modelValue', payload: { orderId, next } })
  const order = orders.value.find(candidate => candidate.id === orderId)
  // Side effect: this local mutation follows the declared child event; no API success is implied.
  if (order) order.status = next
}

// Mapping: expose the complete oracle without reaching into child implementation state.
const evidence = computed(() => JSON.stringify({
  filter: filter.value,
  selectedId: selectedId.value,
  orders: orders.value,
  events: eventTrace.value,
}))
</script>

<template>
  <section aria-labelledby="contract-title">
    <h2 id="contract-title">父级唯一状态所有权</h2>
    <FilterBar v-model="filter" />
    <p data-testid="selection">选择：{{ selectedId ?? '无' }}</p>

    <p v-if="visibleOrders.length === 0" role="status">当前筛选没有工单，请切换条件。</p>
    <OrderCard
      v-for="order in visibleOrders"
      :key="order.id"
      :order="order"
      :selected="selectedId === order.id"
      @select="handleSelect"
    >
      <template #metadata="{ order: slotOrder }">
        <p :data-slot-order-id="slotOrder.id">
          {{ slotOrder.priority }} / {{ slotOrder.status }}
        </p>
      </template>
      <template #actions="{ orderId, status }">
        <StatusEditor
          :order-id="orderId"
          :model-value="status"
          @update:model-value="next => handleStatus(orderId, next)"
        />
      </template>
    </OrderCard>

    <output data-testid="evidence">{{ evidence }}</output>
  </section>
</template>

