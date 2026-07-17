import {
  createRouter,
  createWebHistory,
  type RouterHistory,
  type RouteRecordRaw,
} from 'vue-router'
import type { NavigationSession, NavigationTrace } from './navigation-contracts'
import { normalizeStatusQuery, toNavigationTrace } from './navigation-contracts'
import NotFoundPage from './pages/NotFoundPage.vue'
import SignInPage from './pages/SignInPage.vue'
import WorkOrderDetailPage from './pages/WorkOrderDetailPage.vue'
import WorkOrderLayout from './pages/WorkOrderLayout.vue'
import WorkOrderListPage from './pages/WorkOrderListPage.vue'

// Responsibility: route records are the single URL-to-layout/page matrix for this feature.
export const routes: RouteRecordRaw[] = [
  { path: '/', redirect: { name: 'work-order-list' } },
  {
    path: '/sign-in',
    name: 'sign-in',
    component: SignInPage,
    props: (route) => ({ redirect: typeof route.query.redirect === 'string' ? route.query.redirect : '/' }),
  },
  {
    path: '/work-orders',
    component: WorkOrderLayout,
    children: [
      {
        path: '',
        name: 'work-order-list',
        component: WorkOrderListPage,
        props: (route) => ({ status: normalizeStatusQuery(route.query.status) }),
      },
      {
        path: ':workOrderId',
        name: 'work-order-detail',
        component: WorkOrderDetailPage,
        // Mapping: pages receive a normal prop and do not depend on the whole route object.
        props: (route) => ({ workOrderId: String(route.params.workOrderId) }),
        meta: { requiresSession: true },
      },
    ],
  },
  { path: '/:pathMatch(.*)*', name: 'not-found', component: NotFoundPage },
]

export function createFactoryCareRouter(
  history: RouterHistory,
  session: NavigationSession,
  trace: NavigationTrace[] = [],
) {
  const router = createRouter({ history, routes })

  router.beforeEach((to, from) => {
    // Navigation guard: cancel departure while this client-side draft still needs confirmation.
    if (from.name === 'work-order-detail' && session.hasUnsavedDraft && to.fullPath !== from.fullPath) {
      return false
    }
    // Boundary: this redirect improves UX but is never treated as server authorization evidence.
    if (to.meta.requiresSession && !session.authenticated) {
      return { name: 'sign-in', query: { redirect: to.fullPath } }
    }
    return true
  })

  // Side effect: afterEach records success/failure without changing the navigation result.
  router.afterEach((to, from, failure) => trace.push(toNavigationTrace(to, from, failure)))
  return router
}

export const browserSession: NavigationSession = { authenticated: true, hasUnsavedDraft: false }
export const router = createFactoryCareRouter(createWebHistory(), browserSession)

