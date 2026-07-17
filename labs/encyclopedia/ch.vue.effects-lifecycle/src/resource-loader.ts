export type Filter = 'ALL' | 'CREATED' | 'COMPLETED'

export type Order = {
  id: string
  title: string
  status: 'CREATED' | 'COMPLETED'
}

const fixtures: Record<Filter, Order[]> = {
  ALL: [
    { id: 'WO-1', title: '主轴过热', status: 'CREATED' },
    { id: 'WO-2', title: '滤芯更换', status: 'COMPLETED' },
  ],
  CREATED: [{ id: 'WO-1', title: '主轴过热', status: 'CREATED' }],
  COMPLETED: [{ id: 'WO-2', title: '滤芯更换', status: 'COMPLETED' }],
}

const latency: Record<Filter, number> = { ALL: 40, CREATED: 10, COMPLETED: 25 }

export function createResourceLoader() {
  // Data source: activeCount belongs to one component instance's controlled resource factory.
  let activeCount = 0

  function list(filter: Filter, signal: AbortSignal, record: (event: string) => void) {
    activeCount += 1
    record(`resource-open:${filter}`)

    // Side effect: one timer represents one cancellable external resource.
    return new Promise<Order[]>((resolve, reject) => {
      let settled = false
      const timer = setTimeout(() => {
        if (settled) return
        settled = true
        activeCount -= 1
        signal.removeEventListener('abort', abort)
        record(`resource-close:resolve:${filter}`)
        resolve(fixtures[filter].map(order => ({ ...order })))
      }, latency[filter])

      function abort() {
        if (settled) return
        settled = true
        clearTimeout(timer)
        activeCount -= 1
        record(`resource-close:abort:${filter}`)
        reject(new DOMException('The operation was aborted', 'AbortError'))
      }

      signal.addEventListener('abort', abort, { once: true })
    })
  }

  return { list, active: () => activeCount }
}
