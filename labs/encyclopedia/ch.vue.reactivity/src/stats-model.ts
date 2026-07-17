import { computed, reactive, readonly, ref, toRef } from 'vue'

export type Status = 'CREATED' | 'IN_PROGRESS' | 'COMPLETED'
export type Filter = 'ALL' | Status

export type WorkOrder = {
  id: string
  title: string
  status: Status
  priority: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'
}

export function createStatsModel(seed: WorkOrder[]) {
  // Data source: the model owns copies so callers cannot silently mutate the original seed.
  const orders = ref(seed.map(order => ({ ...order })))
  const filter = reactive({ status: 'ALL' as Filter })
  let openEvaluations = 0
  let visibleEvaluations = 0
  let criticalEvaluations = 0

  const openCount = computed(() => {
    // Mapping: derive the count from source status; the counter is observation-only.
    openEvaluations += 1
    return orders.value.filter(order => order.status !== 'COMPLETED').length
  })

  const criticalCount = computed(() => {
    // Mapping: this independent derivation reads orders but never reads the filter.
    criticalEvaluations += 1
    return orders.value.filter(order => order.priority === 'CRITICAL').length
  })

  const visibleOrders = computed(() => {
    // Mapping: visible rows depend on both the collection and the selected status.
    visibleEvaluations += 1
    return orders.value.filter(order =>
      filter.status === 'ALL' ? true : order.status === filter.status,
    )
  })

  function addOrder(order: WorkOrder) {
    // Side effect: mutate only the owned source; all counts remain read-only derivations.
    orders.value.push({ ...order })
  }

  function completeOrder(id: string) {
    const order = orders.value.find(candidate => candidate.id === id)
    if (order) order.status = 'COMPLETED'
  }

  function replaceOrders(next: WorkOrder[]) {
    // Side effect: whole-collection replacement preserves the ref container identity.
    orders.value = next.map(order => ({ ...order }))
  }

  function setFilter(status: Filter) {
    filter.status = status
  }

  return {
    ordersView: readonly(orders),
    filterView: readonly(filter),
    openCount,
    criticalCount,
    visibleOrders,
    addOrder,
    completeOrder,
    replaceOrders,
    setFilter,
    evaluations: () => ({
      open: openEvaluations,
      critical: criticalEvaluations,
      visible: visibleEvaluations,
    }),
  }
}

export function observeDestructuring() {
  const state = reactive({ status: 'CREATED' as Status })
  const { status: snapshot } = state
  const linked = toRef(state, 'status')
  state.status = 'IN_PROGRESS'

  // Mapping: keep the stale snapshot beside the live proxy and toRef evidence.
  return { snapshot, proxyValue: state.status, linkedValue: linked.value }
}

export function observeProxyIdentity() {
  const raw = { query: '' }
  const proxy = reactive(raw)

  // Mapping: public strict-equality observations are stable enough for the chapter oracle.
  return {
    rawDiffersFromProxy: raw !== proxy,
    sameRawReturnsSameProxy: reactive(raw) === proxy,
    proxyInputStaysStable: reactive(proxy) === proxy,
  }
}

