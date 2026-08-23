import { onScopeDispose, readonly, ref, shallowRef, watch } from 'vue'
import type { WorkOrder, WorkOrderRepository, WorkOrderStatus } from './contracts'

// Responsibility: own per-invocation query state, async invalidation, and its cleanup contract.
export function useWorkOrderQuery(repository: WorkOrderRepository, initial: WorkOrderStatus = 'CREATED') {
  const status = ref<WorkOrderStatus>(initial)
  const orders = shallowRef<readonly WorkOrder[]>([])
  const loading = ref(false)
  const error = shallowRef<Error | null>(null)
  const revision = ref(0)
  let runId = 0

  const stop = watch([status, revision], async ([nextStatus], _previous, onCleanup) => {
    const controller = new AbortController()
    const mine = ++runId
    loading.value = true
    error.value = null
    // Important side effect: every run owns an AbortController disposed on invalidation or scope stop.
    onCleanup(() => controller.abort())
    try {
      const next = await repository.search(nextStatus, controller.signal)
      if (mine === runId) orders.value = next
    } catch (cause) {
      const aborted = cause instanceof DOMException && cause.name === 'AbortError'
      if (!aborted && mine === runId) error.value = cause instanceof Error ? cause : new Error(String(cause))
    } finally {
      if (mine === runId) loading.value = false
    }
  }, { immediate: true })

  onScopeDispose(stop)

  return {
    status: readonly(status), orders: readonly(orders), loading: readonly(loading), error: readonly(error),
    setStatus: (next: WorkOrderStatus) => { status.value = next },
    reload: () => { revision.value += 1 },
  }
}

