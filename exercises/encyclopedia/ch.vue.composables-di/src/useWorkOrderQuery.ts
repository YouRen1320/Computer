import { ref, shallowRef, watch } from 'vue'
import type { WorkOrderRepository, WorkOrderStatus } from './work-order'

// TODO fault: module scope silently shares these refs across every component instance.
const status = ref<WorkOrderStatus>('CREATED')
const orders = shallowRef<readonly { id: string }[]>([])

// Responsibility: query work orders without leaking state or in-flight work between callers.
export function useWorkOrderQuery(repository: WorkOrderRepository) {
  watch(status, async (nextStatus) => {
    orders.value = await repository.search(nextStatus)
  }, { immediate: true })

  return { status, orders }
}

