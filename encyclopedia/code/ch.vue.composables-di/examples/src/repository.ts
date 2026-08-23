import type { WorkOrderRepository, WorkOrderStatus, WorkOrderSummary } from './contracts'

export type RepositoryTrace = Readonly<{
  event: 'start' | 'resolve' | 'abort'
  status: WorkOrderStatus
}>

export type ControlledRequest = Readonly<{
  status: WorkOrderStatus
  signal: AbortSignal
  resolve: (orders: readonly WorkOrderSummary[]) => void
}>

// Responsibility: expose an observable fake without changing the production repository port.
export function createControlledRepository() {
  const trace: RepositoryTrace[] = []
  const requests: ControlledRequest[] = []
  let active = 0

  const repository: WorkOrderRepository = {
    search(status, signal) {
      active += 1
      trace.push({ event: 'start', status })

      return new Promise((resolve, reject) => {
        let settled = false
        const finish = (event: 'resolve' | 'abort', action: () => void) => {
          if (settled) return
          settled = true
          active -= 1
          trace.push({ event, status })
          action()
        }
        const onAbort = () => finish('abort', () => reject(new DOMException('aborted', 'AbortError')))
        signal.addEventListener('abort', onAbort, { once: true })
        requests.push({
          status,
          signal,
          resolve: (orders) => finish('resolve', () => resolve(orders)),
        })
      })
    },
  }

  return {
    repository,
    requests,
    trace,
    // Data source: active is derived from unsettled repository calls, not from component loading flags.
    activeCount: () => active,
  }
}

export function createImmediateRepository(
  orders: readonly WorkOrderSummary[],
  calls: WorkOrderStatus[] = [],
): WorkOrderRepository {
  return {
    async search(status, signal) {
      calls.push(status)
      if (signal.aborted) throw new DOMException('aborted', 'AbortError')
      return orders.filter((order) => order.status === status)
    },
  }
}

