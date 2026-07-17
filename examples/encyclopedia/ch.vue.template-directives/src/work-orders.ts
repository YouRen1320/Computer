export type WorkOrderStatus = 'CREATED' | 'IN_PROGRESS' | 'CLOSED'
export type Priority = 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'

export interface WorkOrderListItem {
  id: string
  number: string
  status: WorkOrderStatus
  priority: Priority
  createdAt: string
}

// 固定夹具来自 FactoryCare 公共工单字段的最小只读投影，不代表服务器真实响应。
export const fixtureOrders: WorkOrderListItem[] = [
  { id: 'wo-a', number: 'WO-2026-001', status: 'CREATED', priority: 'HIGH', createdAt: '2026-07-17T01:00:00Z' },
  { id: 'wo-b', number: 'WO-2026-002', status: 'IN_PROGRESS', priority: 'CRITICAL', createdAt: '2026-07-17T02:00:00Z' },
  { id: 'wo-c', number: 'WO-2026-003', status: 'CLOSED', priority: 'LOW', createdAt: '2026-07-17T03:00:00Z' },
]
