import { createRouter, createWebHistory, type RouterHistory, type RouteRecordRaw } from 'vue-router'
import { normalizeStatus, type Session, type Trace } from './contracts'
import NotFound from './pages/NotFound.vue'
import OrderDetail from './pages/OrderDetail.vue'
import OrderList from './pages/OrderList.vue'
import SignIn from './pages/SignIn.vue'
import WorkOrderShell from './pages/WorkOrderShell.vue'

// Responsibility: keep the testable URL/component/guard matrix in one explicit route table.
export const routeRecords: RouteRecordRaw[] = [
  { path: '/', redirect: { name: 'orders' } },
  { path: '/sign-in', name: 'sign-in', component: SignIn, props: (route) => ({ redirect: typeof route.query.redirect === 'string' ? route.query.redirect : '/' }) },
  {
    path: '/work-orders',
    component: WorkOrderShell,
    children: [
      { path: '', name: 'orders', component: OrderList, props: (route) => ({ status: normalizeStatus(route.query.status) }) },
      {
        path: ':workOrderId', name: 'order-detail', component: OrderDetail,
        // Mapping: route-specific data enters the page as a normal typed prop.
        props: (route) => ({ workOrderId: String(route.params.workOrderId) }),
        meta: { requiresSession: true },
      },
    ],
  },
  { path: '/:pathMatch(.*)*', name: 'not-found', component: NotFound },
]

export function makeRouter(history: RouterHistory, session: Session, trace: Trace[] = []) {
  const router = createRouter({ history, routes: routeRecords })

  router.beforeEach((to, from) => {
    // Side effect boundary: cancellation preserves URL/component tree while an unsaved draft is owned here.
    if (from.name === 'order-detail' && session.unsavedDetail && to.fullPath !== from.fullPath) return false
    // This route policy only redirects navigation; the API/server must enforce data authorization.
    if (to.meta.requiresSession && !session.authenticated) return { name: 'sign-in', query: { redirect: to.fullPath } }
    return true
  })

  router.afterEach((to, from, failure) => trace.push({
    to: to.fullPath, from: from.fullPath, result: failure ? 'failure' : 'success',
    ...(failure ? { type: failure.type } : {}),
  }))
  return router
}

export const router = makeRouter(createWebHistory(), { authenticated: true, unsavedDetail: false })

