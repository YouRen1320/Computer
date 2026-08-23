import { flushPromises, mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import {
  createMemoryHistory,
  isNavigationFailure,
  NavigationFailureType,
  type Router,
} from 'vue-router'
import App from '../src/App.vue'
import type { NavigationSession, NavigationTrace } from '../src/navigation-contracts'
import { createFactoryCareRouter } from '../src/router'

async function mountAt(path: string, session: NavigationSession = { authenticated: true, hasUnsavedDraft: false }) {
  const trace: NavigationTrace[] = []
  const router = createFactoryCareRouter(createMemoryHistory(), session, trace)
  await router.push(path)
  await router.isReady()
  const wrapper = mount(App, { attachTo: document.body, global: { plugins: [router] } })
  await flushPromises()
  return { wrapper, router, trace, session }
}

async function dispose(wrapper: ReturnType<typeof mount>, router: Router) {
  wrapper.unmount()
  await router.replace('/')
  document.body.innerHTML = ''
}

// Responsibility: verify URL, matched component tree, and navigation result as one route matrix.
describe('FactoryCare route matrix', () => {
  it('renders a protected deep link through the nested layout when authenticated', async () => {
    const { wrapper, router } = await mountAt('/work-orders/WO-3001?from=list')
    expect(router.currentRoute.value.name).toBe('work-order-detail')
    expect(router.currentRoute.value.matched).toHaveLength(2)
    expect(wrapper.get('#work-orders-section-title').text()).toBe('工单中心')
    expect(wrapper.get('[data-testid="detail-id"]').text()).toContain('WO-3001')
    await dispose(wrapper, router)
  })

  it('maps only real status names from the query into the list prop', async () => {
    const valid = await mountAt('/work-orders?status=IN_PROGRESS')
    expect(valid.wrapper.get('[data-testid="status-filter"]').text()).toContain('IN_PROGRESS')
    await dispose(valid.wrapper, valid.router)
    const invalid = await mountAt('/work-orders?status=UNKNOWN')
    expect(invalid.wrapper.get('[data-testid="status-filter"]').text()).toContain('ALL')
    await dispose(invalid.wrapper, invalid.router)
  })

  it('builds encoded URLs with named programmatic navigation', async () => {
    const { wrapper, router } = await mountAt('/work-orders')
    await router.push({ name: 'work-order-detail', params: { workOrderId: 'WO 30/03' }, query: { from: 'search' } })
    await flushPromises()
    expect(router.currentRoute.value.params.workOrderId).toBe('WO 30/03')
    expect(router.currentRoute.value.fullPath).toBe('/work-orders/WO%2030%2F03?from=search')
    await dispose(wrapper, router)
  })

  it('refreshes data when a reused detail component receives a new param', async () => {
    const { wrapper, router } = await mountAt('/work-orders/WO-3001')
    await router.push({ name: 'work-order-detail', params: { workOrderId: 'WO-3002' } })
    await flushPromises()
    expect(wrapper.get('[data-testid="detail-id"]').text()).toContain('WO-3002')
    expect(wrapper.get('[data-testid="load-count"]').text()).toContain('2')
    await dispose(wrapper, router)
  })

  it('returns an aborted failure and preserves the URL when navigation is cancelled', async () => {
    const context = await mountAt('/work-orders/WO-3001')
    context.session.hasUnsavedDraft = true
    const failure = await context.router.push({ name: 'work-order-list' })
    expect(isNavigationFailure(failure, NavigationFailureType.aborted)).toBe(true)
    expect(context.router.currentRoute.value.fullPath).toBe('/work-orders/WO-3001')
    expect(context.trace.at(-1)?.result).toBe('failure')
    context.session.hasUnsavedDraft = false
    await dispose(context.wrapper, context.router)
  })

  it('redirects an unauthenticated deep link once without creating a guard loop', async () => {
    const context = await mountAt('/work-orders/WO-3001', { authenticated: false, hasUnsavedDraft: false })
    expect(context.router.currentRoute.value.name).toBe('sign-in')
    expect(context.router.currentRoute.value.query.redirect).toBe('/work-orders/WO-3001')
    expect(context.wrapper.get('[data-testid="redirect-target"]').text()).toContain('/work-orders/WO-3001')
    expect(context.trace.length).toBeLessThan(4)
    await dispose(context.wrapper, context.router)
  })

  it('renders the catch-all page for an unknown direct URL', async () => {
    const { wrapper, router } = await mountAt('/missing/deep/link')
    expect(router.currentRoute.value.name).toBe('not-found')
    expect(wrapper.get('[data-page-title]').text()).toBe('页面不存在')
    await dispose(wrapper, router)
  })

  it('exposes current-page semantics on the active RouterLink', async () => {
    const { wrapper, router } = await mountAt('/work-orders?status=CREATED')
    const link = wrapper.get('nav a')
    expect(link.classes()).toContain('router-link-active')
    expect(link.attributes('aria-current')).toBe('page')
    await dispose(wrapper, router)
  })

  it('moves focus to the new page heading after route navigation', async () => {
    const { wrapper, router } = await mountAt('/work-orders')
    await router.push({ name: 'work-order-detail', params: { workOrderId: 'WO-3002' } })
    await flushPromises()
    expect(document.activeElement).toBe(wrapper.get('[data-page-title]').element)
    await dispose(wrapper, router)
  })
})
