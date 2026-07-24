export type WorkOrderStatus = 'CREATED' | 'IN_PROGRESS' | 'RESOLVED'

// Data source: concrete HTTP/fake implementations satisfy this replaceable boundary.
export interface WorkOrderRepository {
  search(status: WorkOrderStatus, signal?: AbortSignal): Promise<readonly { id: string }[]>
}

