import { readonly, ref, shallowRef, watch } from 'vue'
import type { WorkOrderRepository, WorkOrderStatus } from './work-order'

// Responsibility: own isolated query state and cancel work invalidated by status changes or unmount.
export function useWorkOrderQuery(repository: WorkOrderRepository) {
  const status = ref<WorkOrderStatus>('CREATED')
  const orders = shallowRef<readonly { id: string }[]>([])

  watch(status, async (nextStatus, _previous, onCleanup) => {
    const controller = new AbortController()
    // Important side effect: Vue invokes this when the watcher reruns or its owner scope stops.
    onCleanup(() => controller.abort())
    orders.value = await repository.search(nextStatus, controller.signal)
  }, { immediate: true })

  // Mapping: observation is readonly; mutation remains an explicit command owned here.
  return {
    status: readonly(status),
    orders: readonly(orders),
    setStatus(next: WorkOrderStatus) { status.value = next },
  }
}

