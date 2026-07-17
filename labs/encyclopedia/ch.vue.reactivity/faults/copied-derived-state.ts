import { ref } from 'vue'
import type { WorkOrder } from '../src/stats-model'

export function createCopiedCountFault(seed: WorkOrder[]) {
  // Data source fault: openCount is copied once instead of remaining derived from orders.
  const orders = ref(seed.map(order => ({ ...order })))
  const openCount = ref(orders.value.filter(order => order.status !== 'COMPLETED').length)

  function addOrder(order: WorkOrder) {
    // Injected side effect: this path changes orders but intentionally forgets the copied count.
    orders.value.push({ ...order })
  }

  return { orders, openCount, addOrder }
}

