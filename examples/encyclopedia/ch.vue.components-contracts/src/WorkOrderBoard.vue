<script setup lang="ts">
import { computed, ref } from 'vue'
import WorkOrderCard from './WorkOrderCard.vue'
import WorkOrderFilterBar from './WorkOrderFilterBar.vue'
import WorkOrderStatusEditor from './WorkOrderStatusEditor.vue'
import { fixtureOrders, type StatusFilter, type WorkOrder, type WorkOrderStatus } from './work-order'

// Data source: the parent owns collection, filter, and selection; children receive only views.
const orders = ref<WorkOrder[]>(fixtureOrders.map(order => ({ ...order })))
const filter = ref<StatusFilter>('ALL')
const selectedOrderId = ref<string | null>(null)

const visibleOrders = computed(() => orders.value.filter(order =>
  filter.value === 'ALL' ? true : order.status === filter.value,
))

function selectOrder(payload: { orderId: string }) {
  // Side effect: only the parent mutates its selected identity after the declared child event.
  selectedOrderId.value = payload.orderId
}

function updateStatus(orderId: string, nextStatus: WorkOrderStatus) {
  const order = orders.value.find(candidate => candidate.id === orderId)
  // Side effect: this local demo updates the parent source; a real API command is out of scope.
  if (order) order.status = nextStatus
}

// Mapping: explicit evidence lets tests compare parent state with the rendered child contract.
const parentEvidence = computed(() => JSON.stringify({
  filter: filter.value,
  selectedOrderId: selectedOrderId.value,
  orders: orders.value,
}))
</script>

<template>
  <section aria-labelledby="board-title">
    <h2 id="board-title">工单板</h2>
    <WorkOrderFilterBar v-model="filter" />
    <p data-testid="selected">已选择：{{ selectedOrderId ?? '无' }}</p>

    <p v-if="visibleOrders.length === 0" role="status">当前筛选没有工单，请更换筛选。</p>
    <WorkOrderCard
      v-for="order in visibleOrders"
      :key="order.id"
      :order="order"
      :selected="selectedOrderId === order.id"
      @select="selectOrder"
    >
      <template #metadata="{ order: slotOrder }">
        <p :data-testid="`metadata-${slotOrder.id}`">
          {{ slotOrder.id }} / {{ slotOrder.priority }}
        </p>
      </template>

      <template #actions="{ orderId, status }">
        <WorkOrderStatusEditor
          :model-value="status"
          @update:model-value="next => updateStatus(orderId, next)"
        />
      </template>
    </WorkOrderCard>

    <output data-testid="parent-evidence">{{ parentEvidence }}</output>
  </section>
</template>

