import { computed, ref } from 'vue'

type WorkOrder = {
  id: string
  status: 'CREATED' | 'IN_PROGRESS' | 'RESOLVED'
}

export function createStatsModel(initialOrders: WorkOrder[]) {
  // Data source: the collection is the only writable owner of work-order status facts.
  const orders = ref(initialOrders.map(order => ({ ...order })))
  const openCount = computed(() =>
    // Mapping: rebuild the read-only count from the current source on invalidation.
    orders.value.filter(order => order.status !== 'RESOLVED').length,
  )

  function addOrder(order: WorkOrder) {
    // Side effect: mutate one source; computed invalidation supplies the next count.
    orders.value.push({ ...order })
  }

  return { orders, openCount, addOrder }
}

