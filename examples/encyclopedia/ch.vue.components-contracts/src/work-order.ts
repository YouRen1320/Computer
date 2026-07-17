export type WorkOrderStatus = 'CREATED' | 'IN_PROGRESS' | 'COMPLETED'
export type StatusFilter = 'ALL' | WorkOrderStatus

export type WorkOrder = {
  id: string
  title: string
  status: WorkOrderStatus
  priority: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'
}

// Data source: stable fixture identities make parent/child transitions reproducible.
export const fixtureOrders: WorkOrder[] = [
  { id: 'WO-1', title: '主轴过热', status: 'CREATED', priority: 'HIGH' },
  { id: 'WO-2', title: '滤芯更换', status: 'COMPLETED', priority: 'LOW' },
]

