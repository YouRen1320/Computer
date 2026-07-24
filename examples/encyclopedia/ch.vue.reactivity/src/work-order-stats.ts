import { computed, reactive, readonly, ref, toRef } from 'vue'

export type WorkOrderStatus = 'CREATED' | 'IN_PROGRESS' | 'RESOLVED'
export type StatusFilter = 'ALL' | WorkOrderStatus

export type WorkOrder = {
  id: string
  title: string
  status: WorkOrderStatus
  priority: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'
}

export function createWorkOrderStats(initialOrders: WorkOrder[]) {
  // Data source: the model owns an array copy and one stable filter proxy.
  const orders = ref(initialOrders.map(order => ({ ...order })))
  const filter = reactive({ status: 'ALL' as StatusFilter })
  let openEvaluations = 0
  let visibleEvaluations = 0

  const openCount = computed(() => {
    // Mapping: the counter is a test probe; the returned count remains a pure derivation.
    openEvaluations += 1
    return orders.value.filter(order => order.status !== 'RESOLVED').length
  })

  const visibleOrders = computed(() => {
    // Mapping: only this derivation depends on both the order source and status filter.
    visibleEvaluations += 1
    return orders.value.filter(order =>
      filter.status === 'ALL' ? true : order.status === filter.status,
    )
  })

  function addOrder(order: WorkOrder) {
    // Side effect: this synchronous command mutates the owned source, not external state.
    orders.value.push({ ...order })
  }

  function setStatusFilter(status: StatusFilter) {
    // Side effect: keep filter writes behind one small command for observable transitions.
    filter.status = status
  }

  return {
    orders: readonly(orders),
    filter: readonly(filter),
    openCount,
    visibleOrders,
    addOrder,
    setStatusFilter,
    evaluationCounts: () => ({ open: openEvaluations, visible: visibleEvaluations }),
  }
}

export function observeIdentityBoundaries() {
  const raw = { status: 'CREATED' as WorkOrderStatus }
  const proxy = reactive(raw)
  const { status: snapshot } = proxy
  const linkedStatus = toRef(proxy, 'status')
  proxy.status = 'IN_PROGRESS'

  const selectedId = ref('WO-1')
  const objectContainer = reactive({ selectedId })
  const arrayContainer = reactive([selectedId])

  // Mapping: return public observations rather than Vue's private dependency structures.
  return {
    proxyDiffersFromRaw: proxy !== raw,
    repeatedProxyIsStable: reactive(raw) === proxy,
    snapshot,
    proxyStatus: proxy.status,
    linkedStatus: linkedStatus.value,
    objectUnwrapped: objectContainer.selectedId,
    arrayKeepsRefValue: arrayContainer[0].value,
  }
}

