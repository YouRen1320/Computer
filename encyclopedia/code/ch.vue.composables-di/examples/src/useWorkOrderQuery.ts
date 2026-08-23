import { onScopeDispose, readonly, ref, shallowRef, watch } from 'vue'
import type { WorkOrderRepository, WorkOrderStatus, WorkOrderSummary } from './contracts'

function isAbortError(error: unknown) {
  return error instanceof DOMException && error.name === 'AbortError'
}

// Responsibility: own one caller's query state and exactly one in-flight repository effect.
export function useWorkOrderQuery(
  repository: WorkOrderRepository,
  initialStatus: WorkOrderStatus = 'CREATED',
) {
  // Instance scope: every invocation creates fresh refs; no mutable query state lives at module scope.
  const status = ref<WorkOrderStatus>(initialStatus)
  const revision = ref(0)
  const orders = shallowRef<readonly WorkOrderSummary[]>([])
  const loading = ref(false)
  const error = shallowRef<Error | null>(null)
  let generation = 0

  const stop = watch(
    [status, revision],
    async ([nextStatus], _previous, onCleanup) => {
      const controller = new AbortController()
      const currentGeneration = ++generation
      loading.value = true
      error.value = null

      // Important side effect: invalidation/unmount aborts the request owned by this watcher run.
      onCleanup(() => controller.abort())

      try {
        const result = await repository.search(nextStatus, controller.signal)
        if (currentGeneration === generation) orders.value = result
      } catch (cause) {
        if (!isAbortError(cause) && currentGeneration === generation) {
          error.value = cause instanceof Error ? cause : new Error(String(cause))
        }
      } finally {
        if (currentGeneration === generation) loading.value = false
      }
    },
    { immediate: true },
  )

  // Ownership: stopping the component/effect scope invokes the active watcher's cleanup.
  onScopeDispose(stop)

  function setStatus(nextStatus: WorkOrderStatus) {
    status.value = nextStatus
  }

  function reload() {
    revision.value += 1
  }

  // Output contract: consumers observe readonly refs and request mutations through commands.
  return {
    status: readonly(status),
    orders: readonly(orders),
    loading: readonly(loading),
    error: readonly(error),
    setStatus,
    reload,
  }
}

