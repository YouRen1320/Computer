import { describe, expect, it } from 'vitest'
import { parseWorkOrder } from '../src/work-order-schema.js'

const validPayload = {
  id: 'WO-101',
  title: '泵体温度异常',
  status: 'IN_PROGRESS',
  priority: 4,
  createdAt: '2026-07-17T08:00:00+08:00',
  assigneeId: null,
}

// 测试矩阵覆盖合法、缺失、额外和错误类型四类边界输入。
describe('WorkOrder runtime boundary', () => {
  it('narrows a valid payload', () => {
    const result = parseWorkOrder(validPayload)
    expect(result.ok).toBe(true)
    if (result.ok) expect(result.value.status).toBe('IN_PROGRESS')
  })

  it.each([
    ['missing status', (({ status: _status, ...rest }) => rest)(validPayload)],
    ['extra field', { ...validPayload, internalCost: 800 }],
    ['wrong priority type', { ...validPayload, priority: '4' }],
    ['unknown status', { ...validPayload, status: 'NOT_A_STATE' }],
  ])('rejects %s', (_name, payload) => {
    const result = parseWorkOrder(payload)
    expect(result.ok).toBe(false)
    if (!result.ok) expect(result.issues.length).toBeGreaterThan(0)
  })
})
