export type WorkOrderStatus = 'CREATED' | 'IN_PROGRESS' | 'COMPLETED'
export interface WorkOrderSummary { id: string; title: string; status: WorkOrderStatus }

// Data source boundary: tests replace only this gateway, while keeping the real component contract.
export interface WorkOrderGateway {
  list(status: WorkOrderStatus, signal: AbortSignal): Promise<readonly WorkOrderSummary[]>
}
