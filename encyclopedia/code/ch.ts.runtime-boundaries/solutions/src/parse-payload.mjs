const statuses = new Set(['ASSIGNED', 'IN_PROGRESS', 'CLOSED'])

// 私有参考边界显式拒绝额外键、缺失键和错误类型，不依赖 TypeScript 断言。
export function parsePayload(input) {
  if (typeof input !== 'object' || input === null || Array.isArray(input)) return { ok: false }
  const keys = Object.keys(input).sort()
  if (keys.join(',') !== 'id,priority,status') return { ok: false }
  if (typeof input.id !== 'string' || !/^WO-[0-9]+$/.test(input.id)) return { ok: false }
  if (typeof input.priority !== 'number' || !Number.isInteger(input.priority)) return { ok: false }
  if (input.priority < 1 || input.priority > 5 || !statuses.has(input.status)) return { ok: false }
  return { ok: true, value: { id: input.id, status: input.status, priority: input.priority } }
}

