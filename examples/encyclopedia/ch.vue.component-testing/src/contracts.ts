export type WorkOrderStatus = 'CREATED' | 'IN_PROGRESS' | 'RESOLVED'

export type WorkOrderSummary = Readonly<{
  id: string
  title: string
  status: WorkOrderStatus
}>

// Responsibility: expose the smallest network boundary used by the component under test.
export interface WorkOrderGateway {
  list(status: WorkOrderStatus, signal: AbortSignal): Promise<readonly WorkOrderSummary[]>
}

export const httpWorkOrderGateway: WorkOrderGateway = {
  async list(status, signal) {
    // Data source: production-shaped data enters through one HTTP boundary that E2E can intercept.
    const response = await fetch(`/api/work-orders?status=${encodeURIComponent(status)}`, { signal })
    if (!response.ok) throw new Error(`工单查询失败（${response.status}）`)
    return response.json() as Promise<readonly WorkOrderSummary[]>
  },
}
