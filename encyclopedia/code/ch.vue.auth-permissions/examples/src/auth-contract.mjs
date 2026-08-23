// Responsibility: model auth bootstrap, safe navigation, capability UI, 401/403 handling, and server-policy separation.
// Data source: injected session responses, untrusted return paths, route metadata, and server-owned subjects/orders.
// Mapping: unknown→authenticated/anonymous/error; route→allow/sign-in/forbidden; API policy→204/401/403.
// Side effects: calls only injected session loader; the policy server mutates no real account, network, or database.

const SAFE_HOME = '/work-orders'

export function safeReturnPath(raw) {
  if (typeof raw !== 'string' || !raw.startsWith('/') || raw.startsWith('//')) return SAFE_HOME
  if (raw.includes('\\') || /[\u0000-\u001f\u007f]/u.test(raw)) return SAFE_HOME
  let parsed
  try {
    parsed = new URL(raw, 'https://factorycare.invalid')
  } catch {
    return SAFE_HOME
  }
  if (parsed.origin !== 'https://factorycare.invalid' || parsed.pathname === '/sign-in') return SAFE_HOME
  return `${parsed.pathname}${parsed.search}${parsed.hash}`
}

export function createAuthClient(loadSession) {
  let state = Object.freeze({ tag: 'unknown' })
  let generation = 0
  let inFlight = null
  const trace = []

  async function bootstrap() {
    if (state.tag === 'authenticated' || state.tag === 'anonymous') return
    if (inFlight) return inFlight
    const ownGeneration = generation
    state = Object.freeze({ tag: 'bootstrapping', generation: ownGeneration })
    trace.push(`bootstrap:start:${ownGeneration}`)
    inFlight = Promise.resolve()
      .then(loadSession)
      .then((response) => {
        if (generation !== ownGeneration) return
        if (response.status === 200) {
          state = Object.freeze({
            tag: 'authenticated',
            subject: Object.freeze({ ...response.subject }),
            capabilities: Object.freeze([...response.capabilities]),
          })
          trace.push('bootstrap:authenticated')
        } else if (response.status === 401) {
          state = Object.freeze({ tag: 'anonymous', reason: 'missing-or-expired' })
          trace.push('bootstrap:anonymous')
        } else {
          state = Object.freeze({ tag: 'bootstrap-error', status: response.status })
          trace.push(`bootstrap:error:${response.status}`)
        }
      })
      .catch((error) => {
        if (generation === ownGeneration) {
          state = Object.freeze({ tag: 'bootstrap-error', message: error instanceof Error ? error.message : String(error) })
          trace.push('bootstrap:network-error')
        }
      })
      .finally(() => {
        if (generation === ownGeneration) inFlight = null
      })
    return inFlight
  }

  function expire(reason = 'expired') {
    generation += 1
    inFlight = null
    state = Object.freeze({ tag: 'anonymous', reason })
    trace.push(`session:${reason}`)
  }

  function can(capability) {
    return state.tag === 'authenticated' && state.capabilities.includes(capability)
  }

  return {
    bootstrap,
    expire,
    can,
    state: () => state,
    trace: () => [...trace],
    sensitiveVisible: () => state.tag === 'authenticated',
  }
}

export async function routeDecision(auth, route) {
  if (route.public) return { kind: 'allow', path: route.fullPath }
  await auth.bootstrap()
  const state = auth.state()
  if (state.tag !== 'authenticated') {
    return { kind: 'sign-in', path: '/sign-in', returnTo: safeReturnPath(route.fullPath) }
  }
  if (route.capability && !auth.can(route.capability)) {
    return { kind: 'forbidden', path: '/forbidden', from: route.fullPath }
  }
  return { kind: 'allow', path: route.fullPath }
}

export function handleApiStatus(auth, status, currentPath) {
  if (status === 401) {
    auth.expire('expired')
    return { kind: 'sign-in', returnTo: safeReturnPath(currentPath) }
  }
  if (status === 403) return { kind: 'forbidden', path: '/forbidden' }
  return { kind: 'unchanged' }
}

export function permissionPresentation(auth, capability) {
  return auth.can(capability) ? { visible: true, reason: null } : { visible: false, reason: 'missing-capability' }
}

export function createPolicyServer({ subjects, orders }) {
  return {
    deleteWorkOrder({ subjectId, workOrderId }) {
      const subject = subjects[subjectId]
      const order = orders[workOrderId]
      if (!subject) return { status: 401, code: 'AUTHENTICATION_REQUIRED' }
      if (!order) return { status: 404, code: 'NOT_FOUND' }
      const allowed = subject.capabilities.includes('work-order.delete')
        && subject.tenantId === order.tenantId
        && order.status !== 'RESOLVED'
      return allowed
        ? { status: 204, code: 'DELETED' }
        : { status: 403, code: 'FORBIDDEN' }
    },
  }
}
