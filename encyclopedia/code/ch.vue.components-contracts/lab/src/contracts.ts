export type Status = 'CREATED' | 'IN_PROGRESS' | 'RESOLVED'
export type Filter = 'ALL' | Status

export type WorkOrder = {
  id: string
  title: string
  status: Status
  priority: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'
}

// Data source: one fixed set makes every parent/child transition and slot payload reproducible.
export const ordersFixture: WorkOrder[] = [
  { id: 'WO-1', title: '主轴过热', status: 'CREATED', priority: 'HIGH' },
  { id: 'WO-2', title: '滤芯更换', status: 'RESOLVED', priority: 'LOW' },
  { id: 'WO-3', title: '电机异响', status: 'IN_PROGRESS', priority: 'CRITICAL' },
]

