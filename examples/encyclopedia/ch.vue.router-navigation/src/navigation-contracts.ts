import type { NavigationFailure, RouteLocationNormalized } from 'vue-router'

export type WorkOrderStatusFilter = 'ALL' | 'CREATED' | 'IN_PROGRESS' | 'COMPLETED'

export type NavigationSession = {
  authenticated: boolean
  hasUnsavedDraft: boolean
}

export type NavigationTrace = Readonly<{
  to: string
  from: string
  result: 'success' | 'failure'
  failureType?: number
}>

// Mapping: unknown or repeated query values collapse to the explicit safe filter default.
export function normalizeStatusQuery(value: RouteLocationNormalized['query']['status']): WorkOrderStatusFilter {
  return value === 'CREATED' || value === 'IN_PROGRESS' || value === 'COMPLETED' ? value : 'ALL'
}

export function toNavigationTrace(
  to: RouteLocationNormalized,
  from: RouteLocationNormalized,
  failure?: NavigationFailure | void,
): NavigationTrace {
  return {
    to: to.fullPath,
    from: from.fullPath,
    result: failure ? 'failure' : 'success',
    ...(failure ? { failureType: failure.type } : {}),
  }
}

