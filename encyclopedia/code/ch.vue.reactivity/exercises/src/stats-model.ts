import { ref } from 'vue'

type WorkOrder = {
  id: string
  status: 'CREATED' | 'IN_PROGRESS' | 'RESOLVED'
}

export function createStatsModel(initialOrders: WorkOrder[]) {
  // Data source fault: both the collection and its derivable count are independently writable.
  const orders = ref(initialOrders.map(order => ({ ...order })))
  const openCount = ref(
    orders.value.filter(order => order.status !== 'RESOLVED').length,
  )

  function addOrder(order: WorkOrder) {
    // Injected side effect: this source write intentionally omits copied-count synchronization.
    orders.value.push({ ...order })
  }

  return { orders, openCount, addOrder }
}

