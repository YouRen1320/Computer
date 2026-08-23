import { flushPromises, mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import { createMemoryHistory, isNavigationFailure, NavigationFailureType } from 'vue-router'
import App from '../src/App.vue'
import { faultyServerRead } from '../faults/client-only-authorization'
import StaleOrderDetail from '../faults/StaleOrderDetail.vue'
import { faultyAuthenticationGuard } from '../faults/loop-guard'
import type { Session, Trace } from '../src/contracts'
import { makeRouter, routeRecords } from '../src/router'

async function mountAt(path: string, session: Session = { authenticated: true, unsavedDetail: false }) {
  const trace: Trace[] = []
  const router = makeRouter(createMemoryHistory(), session, trace)
  await router.push(path)
  await router.isReady()
  const wrapper = mount(App, { global: { plugins: [router] } })
  await flushPromises()
  return { wrapper, router, session, trace }
}

// Responsibility: pair each injected failure with the first observable evidence and fixed route oracle.
describe('router navigation fault matrix', () => {
  it('defines list/detail as children of one work-order layout record', () => {
    const parent = routeRecords.find((record) => record.path === '/work-orders')
    expect(parent?.children?.map((record) => record.name)).toEqual(['orders', 'order-detail'])
  })

  it('renders an authenticated direct detail URL through both matched records', async () => {
    const context = await mountAt('/work-orders/WO-4001')
    expect(context.router.currentRoute.value.matched).toHaveLength(2)
    expect(context.wrapper.get('[data-testid="layout"]').exists()).toBe(true)
    expect(context.wrapper.get('[data-testid="loaded-id"]').text()).toBe('WO-4001')
    context.wrapper.unmount()
  })

  it('normalizes invalid query input at the route-to-prop boundary', async () => {
    const context = await mountAt('/work-orders?status=UNKNOWN')
    expect(context.wrapper.get('[data-testid="filter"]').text()).toBe('ALL')
    context.wrapper.unmount()
  })

  it('updates a reused fixed component when only workOrderId changes', async () => {
    const context = await mountAt('/work-orders/WO-4001')
    await context.router.push({ name: 'order-detail', params: { workOrderId: 'WO-4002' } })
    await flushPromises()
    expect(context.wrapper.get('[data-testid="loaded-id"]').text()).toBe('WO-4002')
    expect(context.wrapper.get('[data-testid="load-count"]').text()).toBe('2')
    context.wrapper.unmount()
  })

  it('detects the stale-param fault on a reused component instance', async () => {
    const wrapper = mount(StaleOrderDetail, { props: { workOrderId: 'WO-4001' } })
    await wrapper.setProps({ workOrderId: 'WO-4002' })
    expect(wrapper.get('[data-testid="faulty-loaded-id"]').text()).toBe('WO-4001')
  })

  it('returns an aborted navigation failure and leaves URL/tree unchanged', async () => {
    const context = await mountAt('/work-orders/WO-4001')
    context.session.unsavedDetail = true
    const failure = await context.router.push({ name: 'orders' })
    expect(isNavigationFailure(failure, NavigationFailureType.aborted)).toBe(true)
    expect(context.router.currentRoute.value.fullPath).toBe('/work-orders/WO-4001')
    expect(context.trace.at(-1)?.result).toBe('failure')
    context.wrapper.unmount()
  })

  it('redirects unauthenticated details but lets sign-in terminate the guard chain', async () => {
    const context = await mountAt('/work-orders/WO-4001', { authenticated: false, unsavedDetail: false })
    expect(context.router.currentRoute.value.name).toBe('sign-in')
    expect(context.router.currentRoute.value.query.redirect).toBe('/work-orders/WO-4001')
    expect(context.trace.length).toBeLessThan(4)
    context.wrapper.unmount()
  })

  it('detects a guard whose unauthenticated sign-in target redirects to itself', () => {
    const first = faultyAuthenticationGuard(false)
    const second = faultyAuthenticationGuard(false)
    expect(first).toEqual({ name: 'sign-in' })
    expect(second).toEqual(first)
  })

  it('proves a client guard cannot compensate for an unauthorized server read', async () => {
    const leaked = await faultyServerRead(undefined, 'WO-4001')
    expect(leaked.maintenanceReport).toContain('内部故障分析')
  })

  it('matches an unknown deep link with the catch-all record', async () => {
    const context = await mountAt('/unknown/branch')
    expect(context.router.currentRoute.value.name).toBe('not-found')
    expect(context.wrapper.get('[data-testid="not-found"]').exists()).toBe(true)
    context.wrapper.unmount()
  })
})
