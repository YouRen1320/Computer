import * as z from 'zod'

// 运行时 Schema 是工单 HTTP 边界的唯一结构真相，静态类型从它推导。
export const WorkOrderSchema = z.strictObject({
  id: z.string().regex(/^WO-[0-9]+$/),
  title: z.string().trim().min(1).max(200),
  status: z.enum(['ASSIGNED', 'IN_PROGRESS', 'CLOSED']),
  priority: z.int().min(1).max(5),
  createdAt: z.iso.datetime({ offset: true }),
  assigneeId: z.int().positive().nullable(),
})

export type WorkOrder = z.infer<typeof WorkOrderSchema>

export type BoundaryIssue = Readonly<{ path: string; code: string }>

export type BoundaryResult<T> =
  | Readonly<{ ok: true; value: T }>
  | Readonly<{ ok: false; kind: 'invalid-payload'; issues: readonly BoundaryIssue[] }>

// safeParse 失败被映射为稳定且脱敏的应用错误，不把原始 payload 写入日志。
export function parseWorkOrder(input: unknown): BoundaryResult<WorkOrder> {
  const result = WorkOrderSchema.safeParse(input)
  if (result.success) return { ok: true, value: result.data }

  return {
    ok: false,
    kind: 'invalid-payload',
    issues: result.error.issues.map((issue) => ({
      path: issue.path.join('.'),
      code: issue.code,
    })),
  }
}

