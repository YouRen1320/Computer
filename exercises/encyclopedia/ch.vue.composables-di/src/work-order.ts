export type WorkOrderStatus = 'CREATED' | 'IN_PROGRESS' | 'RESOLVED'

// Data source: the exercise keeps the repository as a replaceable port.
export interface WorkOrderRepository {
  search(status: WorkOrderStatus, signal?: AbortSignal): Promise<readonly { id: string }[]>
}

