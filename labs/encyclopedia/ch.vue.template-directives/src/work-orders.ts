export type WorkOrderStatus = 'CREATED' | 'IN_PROGRESS' | 'CLOSED'
export type Priority = 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'

export interface WorkOrderListItem {
  id: string
  number: string
  status: WorkOrderStatus
  priority: Priority
  createdAt: string
}

// 固定夹具投影自 public-api.yaml 的工单摘要字段；ID 是列表身份，顺序不是。
export const fixtureOrders: WorkOrderListItem[] = [
  { id: 'wo-a', number: 'WO-2026-101', status: 'CREATED', priority: 'HIGH', createdAt: '2026-07-17T01:00:00Z' },
  { id: 'wo-b', number: 'WO-2026-102', status: 'IN_PROGRESS', priority: 'CRITICAL', createdAt: '2026-07-17T02:00:00Z' },
  { id: 'wo-c', number: 'WO-2026-103', status: 'CLOSED', priority: 'LOW', createdAt: '2026-07-17T03:00:00Z' },
]
