import type { InjectionKey } from 'vue'

export type WorkOrderStatus = 'CREATED' | 'IN_PROGRESS' | 'RESOLVED'
export type WorkOrder = Readonly<{ id: string; title: string; status: WorkOrderStatus }>

// Responsibility: consumer-facing data port; concrete HTTP or fake details stay outside the composable.
export interface WorkOrderRepository {
  search(status: WorkOrderStatus, signal: AbortSignal): Promise<readonly WorkOrder[]>
}

export interface AuditSink {
  record(event: Readonly<{ type: 'QUERY_STARTED'; status: WorkOrderStatus }>): void
}

// Non-obvious mapping: even identical descriptions remain distinct Symbol identities and typed ports.
export const repositoryKey: InjectionKey<WorkOrderRepository> = Symbol('factorycare.service')
export const auditSinkKey: InjectionKey<AuditSink> = Symbol('factorycare.service')

export const fixtureOrders: readonly WorkOrder[] = [
  { id: 'WO-2001', title: '空压机异响', status: 'CREATED' },
  { id: 'WO-2002', title: '冷却泵巡检', status: 'IN_PROGRESS' },
]

