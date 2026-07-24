import { defineComponent, effectScope, isReadonly, nextTick } from 'vue'
import { flushPromises, mount } from '@vue/test-utils'
import { beforeEach, describe, expect, it } from 'vitest'
import { faultyActiveCount, resetFaultyActiveCount, useFaultyLeakySubscription } from '../faults/leaky-effect'
import { useFaultySharedQueryState } from '../faults/shared-query-state'
import { faultyAuditSinkKey, faultyRepositoryKey } from '../faults/string-key-collision'
import QueryPanel from '../src/QueryPanel.vue'
import { auditSinkKey, fixtureOrders, repositoryKey } from '../src/contracts'
import { createControlledRepository, createImmediateRepository } from '../src/controlled-repository'
import { useWorkOrderQuery } from '../src/useWorkOrderQuery'

// Responsibility: pair every injected fault with observable isolation, cleanup, and substitution evidence.
describe('composable and DI fault matrix', () => {
  beforeEach(() => resetFaultyActiveCount())

  it('detects module-level ref pollution as the first shared-state evidence', () => {
    const left = useFaultySharedQueryState()
    const right = useFaultySharedQueryState()
    left.setStatus('RESOLVED')
    expect(right.status.value).toBe('RESOLVED')
    expect(left.status).toBe(right.status)
    left.setStatus('CREATED')
  })

  it('proves fixed invocations own distinct refs', () => {
    const scope = effectScope()
    const [left, right] = scope.run(() => [
      useWorkOrderQuery(createImmediateRepository(fixtureOrders)),
      useWorkOrderQuery(createImmediateRepository(fixtureOrders)),
    ])!
    left.setStatus('RESOLVED')
    expect(left.status.value).toBe('RESOLVED')
    expect(right.status.value).toBe('CREATED')
    expect(left.status).not.toBe(right.status)
    scope.stop()
  })

  it('detects a missing cleanup after scope stop', () => {
    const scope = effectScope()
    scope.run(() => useFaultyLeakySubscription())
    expect(faultyActiveCount()).toBe(1)
    scope.stop()
    expect(faultyActiveCount()).toBe(1)
  })

  it('proves the fixed request effect reaches zero after scope stop', async () => {
    const controlled = createControlledRepository()
    const scope = effectScope()
    scope.run(() => useWorkOrderQuery(controlled.repository))
    expect(controlled.activeCount()).toBe(1)
    scope.stop()
    await flushPromises()
    expect(controlled.activeCount()).toBe(0)
    expect(controlled.pending[0].signal.aborted).toBe(true)
  })

  it('detects colliding string keys and proves typed Symbols remain distinct', () => {
    expect(faultyRepositoryKey).toBe(faultyAuditSinkKey)
    expect(repositoryKey).not.toBe(auditSinkKey)
    expect(typeof repositoryKey).toBe('symbol')
  })

  it('keeps readonly outputs behind explicit commands', () => {
    const scope = effectScope()
    const query = scope.run(() => useWorkOrderQuery(createImmediateRepository(fixtureOrders)))!
    expect(isReadonly(query.status)).toBe(true)
    expect(isReadonly(query.orders)).toBe(true)
    query.setStatus('IN_PROGRESS')
    expect(query.status.value).toBe('IN_PROGRESS')
    scope.stop()
  })

  it('substitutes repositories without changing the query return shape', async () => {
    const callsA: Array<'CREATED' | 'IN_PROGRESS' | 'RESOLVED'> = []
    const callsB: Array<'CREATED' | 'IN_PROGRESS' | 'RESOLVED'> = []
    const scope = effectScope()
    const [a, b] = scope.run(() => [
      useWorkOrderQuery(createImmediateRepository(fixtureOrders, callsA)),
      useWorkOrderQuery(createImmediateRepository([], callsB)),
    ])!
    await flushPromises()
    expect(Object.keys(a)).toEqual(Object.keys(b))
    expect(callsA).toEqual(['CREATED'])
    expect(callsB).toEqual(['CREATED'])
    scope.stop()
  })

  it('proves two mounted consumers do not pollute their selected statuses', async () => {
    const Host = defineComponent({ components: { QueryPanel }, template: '<QueryPanel panel-id="A"/><QueryPanel panel-id="B"/>' })
    const controlled = createControlledRepository()
    const wrapper = mount(Host, { global: { provide: { [repositoryKey as symbol]: controlled.repository } } })
    await nextTick()
    const selects = wrapper.findAll('select')
    await selects[0].setValue('IN_PROGRESS')
    expect((selects[0].element as HTMLSelectElement).value).toBe('IN_PROGRESS')
    expect((selects[1].element as HTMLSelectElement).value).toBe('CREATED')
    wrapper.unmount()
    await flushPromises()
  })

  it('invalidates the old request before starting the replacement', async () => {
    const controlled = createControlledRepository()
    const scope = effectScope()
    const query = scope.run(() => useWorkOrderQuery(controlled.repository))!
    query.setStatus('IN_PROGRESS')
    await nextTick()
    expect(controlled.pending[0].signal.aborted).toBe(true)
    expect(controlled.starts).toEqual(['CREATED', 'IN_PROGRESS'])
    scope.stop()
    await flushPromises()
  })

  it('fails at the consumer boundary when no repository is provided', () => {
    expect(() => mount(QueryPanel, { props: { panelId: 'missing' } })).toThrowError(
      'Missing WorkOrderRepository provider',
    )
  })
})
