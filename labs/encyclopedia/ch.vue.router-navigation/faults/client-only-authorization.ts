export type SensitiveWorkOrder = Readonly<{ id: string; maintenanceReport: string }>

// Injected fault: this server-shaped function returns protected data without any caller/tenant check.
export async function faultyServerRead(_credential: string | undefined, id: string): Promise<SensitiveWorkOrder> {
  return { id, maintenanceReport: '内部故障分析与人员信息' }
}

