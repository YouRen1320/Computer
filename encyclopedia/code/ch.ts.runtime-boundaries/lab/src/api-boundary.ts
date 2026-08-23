import * as z from 'zod'

// API DTO Schema 拒绝额外字段，防止内部成本等字段意外进入客户端可信域。
const Schema = z.strictObject({
  id: z.string().regex(/^WO-[0-9]+$/),
  status: z.enum(['ASSIGNED', 'IN_PROGRESS', 'CLOSED']),
  priority: z.int().min(1).max(5),
})

export type WorkOrder = z.infer<typeof Schema>
export type ParseResult =
  | { ok: true; value: WorkOrder }
  | { ok: false; kind: 'invalid-payload'; paths: readonly string[] }

// 输入从 unknown 开始，调用者必须穷尽处理 success/failure 联合。
export function parseApiPayload(input: unknown): ParseResult {
  const parsed = Schema.safeParse(input)
  return parsed.success
    ? { ok: true, value: parsed.data }
    : { ok: false, kind: 'invalid-payload', paths: parsed.error.issues.map((issue) => issue.path.join('.')) }
}

