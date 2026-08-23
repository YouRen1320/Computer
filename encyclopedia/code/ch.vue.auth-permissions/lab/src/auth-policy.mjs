// Responsibility: implement the repaired bootstrap, internal redirect, UI capability, and server-deny contracts.
// Data source: injected session responses, untrusted returnTo, route requirements, and server-owned policy records.
// Mapping: unknown→auth/anonymous; route→allow/sign-in/forbidden; direct API→401/403/204 by server facts.
// Side effects: calls an injected session loader only; all authorization data is an in-memory lab fixture.

export function safeReturnPath(raw) {
  const fallback = '/work-orders'
  if (typeof raw !== 'string' || !raw.startsWith('/') || raw.startsWith('//') || raw.includes('\\')) return fallback
  if (/[\u0000-\u001f\u007f]/u.test(raw)) return fallback
  try {
    const parsed = new URL(raw, 'https://factorycare.invalid')
    if (parsed.origin !== 'https://factorycare.invalid' || parsed.pathname === '/sign-in') return fallback
    return `${parsed.pathname}${parsed.search}${parsed.hash}`
  } catch {
    return fallback
  }
}

export function createSession(loadSession) {
  let state = Object.freeze({ tag: 'unknown' })
  let generation = 0
  let inFlight = null

  function bootstrap() {
    if (state.tag === 'authenticated' || state.tag === 'anonymous') return Promise.resolve()
    if (inFlight) return inFlight
    const ownGeneration = generation
    state = Object.freeze({ tag: 'bootstrapping' })
    inFlight = Promise.resolve(loadSession()).then((response) => {
      if (generation !== ownGeneration) return
      state = response.status === 200
        ? Object.freeze({ tag: 'authenticated', subject: response.subject, capabilities: Object.freeze([...response.capabilities]) })
        : Object.freeze({ tag: 'anonymous', reason: response.status === 401 ? 'expired' : 'unavailable' })
    }).finally(() => {
      if (generation === ownGeneration) inFlight = null
    })
    return inFlight
  }

  function expire() {
    generation += 1
    inFlight = null
    state = Object.freeze({ tag: 'anonymous', reason: 'expired' })
  }

  return {
    bootstrap,
    expire,
    state: () => state,
    can: (capability) => state.tag === 'authenticated' && state.capabilities.includes(capability),
    sensitiveVisible: () => state.tag === 'authenticated',
  }
}

export async function guard(session, route) {
  if (route.public) return { kind: 'allow', path: route.fullPath }
  await session.bootstrap()
  if (session.state().tag !== 'authenticated') return { kind: 'sign-in', returnTo: safeReturnPath(route.fullPath) }
  if (route.capability && !session.can(route.capability)) return { kind: 'forbidden', path: '/forbidden' }
  return { kind: 'allow', path: route.fullPath }
}

export function handleStatus(session, status, path) {
  if (status === 401) {
    session.expire()
    return { kind: 'sign-in', returnTo: safeReturnPath(path) }
  }
  if (status === 403) return { kind: 'forbidden' }
  return { kind: 'unchanged' }
}

export function createPolicyServer(subjects, orders) {
  return {
    deleteOrder(subjectId, orderId) {
      const subject = subjects[subjectId]
      const order = orders[orderId]
      if (!subject) return 401
      if (!order) return 404
      return subject.capabilities.includes('work-order.delete') && subject.tenantId === order.tenantId ? 204 : 403
    },
  }
}
