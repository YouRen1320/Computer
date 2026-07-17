export type StatusFilter = 'ALL' | 'CREATED' | 'COMPLETED'

export type WorkOrderResult = {
  id: string
  title: string
  status: 'CREATED' | 'COMPLETED'
}

const results: Record<StatusFilter, WorkOrderResult[]> = {
  ALL: [
    { id: 'WO-1', title: '主轴过热', status: 'CREATED' },
    { id: 'WO-2', title: '滤芯更换', status: 'COMPLETED' },
  ],
  CREATED: [{ id: 'WO-1', title: '主轴过热', status: 'CREATED' }],
  COMPLETED: [{ id: 'WO-2', title: '滤芯更换', status: 'COMPLETED' }],
}

const delays: Record<StatusFilter, number> = {
  ALL: 40,
  CREATED: 10,
  COMPLETED: 25,
}

export function loadOrders(
  filter: StatusFilter,
  signal: AbortSignal,
  record: (event: string) => void,
): Promise<WorkOrderResult[]> {
  // Side effect: the timer models a cancellable external request with deterministic latency.
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      signal.removeEventListener('abort', abort)
      record(`resource-resolve:${filter}`)
      resolve(results[filter].map(order => ({ ...order })))
    }, delays[filter])

    function abort() {
      clearTimeout(timer)
      record(`resource-abort:${filter}`)
      reject(new DOMException('The operation was aborted', 'AbortError'))
    }

    signal.addEventListener('abort', abort, { once: true })
  })
}
