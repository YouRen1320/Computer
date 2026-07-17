import { describe, expect, it } from 'vitest'
import { injectedFaults } from '../faults/injected-faults.js'
import { parseApiPayload } from '../src/api-boundary.js'

// 同一 oracle 同时覆盖合法收窄、四类非法负载和三类诊断标记。
describe('FactoryCare API boundary', () => {
  it('accepts a legal payload', () => {
    expect(parseApiPayload({ id: 'WO-9', status: 'ASSIGNED', priority: 5 })).toEqual({
      ok: true,
      value: { id: 'WO-9', status: 'ASSIGNED', priority: 5 },
    })
  })

  it.each([
    null,
    { id: 'WO-9', priority: 5 },
    { id: 'WO-9', status: 'DONE', priority: 5 },
    { id: 'WO-9', status: 'ASSIGNED', priority: '5' },
    { id: 'WO-9', status: 'ASSIGNED', priority: 5, internalCost: 10 },
  ])('rejects invalid fixture %#', (payload) => {
    expect(parseApiPayload(payload).ok).toBe(false)
  })

  it('keeps stable diagnostic markers', () => {
    expect(injectedFaults.map((fault) => fault.marker)).toEqual([
      'UNVALIDATED_RUNTIME_DATA',
      'PARSE_FAILURE_IGNORED',
      'QUALITY_GATE_BYPASS',
    ])
  })
})

