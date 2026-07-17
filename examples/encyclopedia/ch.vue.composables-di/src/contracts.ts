import type { InjectionKey } from 'vue'

export type WorkOrderStatus = 'CREATED' | 'IN_PROGRESS' | 'COMPLETED'

export type WorkOrderSummary = Readonly<{
  id: string
  title: string
  status: WorkOrderStatus
}>

// Responsibility: this port is the only data-source contract the query composable consumes.
export interface WorkOrderRepository {
  search(status: WorkOrderStatus, signal: AbortSignal): Promise<readonly WorkOrderSummary[]>
}

// Non-obvious mapping: a typed Symbol prevents unrelated modules with the same label from colliding.
export const workOrderRepositoryKey: InjectionKey<WorkOrderRepository> = Symbol('factorycare.work-order-repository')

export const demoOrders: readonly WorkOrderSummary[] = [
  { id: 'WO-1001', title: '主轴温度异常', status: 'CREATED' },
  { id: 'WO-1002', title: '液压站压力波动', status: 'IN_PROGRESS' },
  { id: 'WO-1003', title: '输送带防护罩复位', status: 'COMPLETED' },
]

