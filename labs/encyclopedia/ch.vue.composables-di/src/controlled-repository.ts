import type { WorkOrder, WorkOrderRepository, WorkOrderStatus } from './contracts'

export function createControlledRepository() {
  let active = 0
  const starts: WorkOrderStatus[] = []
  const pending: Array<{ status: WorkOrderStatus; signal: AbortSignal; resolve: (orders: readonly WorkOrder[]) => void }> = []

  const repository: WorkOrderRepository = {
    search(status, signal) {
      active += 1
      starts.push(status)
      return new Promise((resolve, reject) => {
        let settled = false
        const settle = (action: () => void) => {
          if (settled) return
          settled = true
          active -= 1
          action()
        }
        signal.addEventListener('abort', () => settle(() => reject(new DOMException('aborted', 'AbortError'))), { once: true })
        pending.push({ status, signal, resolve: (orders) => settle(() => resolve(orders)) })
      })
    },
  }

  // Data source: active counts unsettled port calls, so zero is an externally observable cleanup oracle.
  return { repository, starts, pending, activeCount: () => active }
}

export function createImmediateRepository(orders: readonly WorkOrder[], calls: WorkOrderStatus[] = []): WorkOrderRepository {
  return {
    async search(status, signal) {
      calls.push(status)
      if (signal.aborted) throw new DOMException('aborted', 'AbortError')
      return orders.filter((order) => order.status === status)
    },
  }
}

