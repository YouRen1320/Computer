// Responsibility: implement safe auth bootstrap, redirect validation, HTTP status handling, and server authority.
// Data source: injected session responses, untrusted return paths, and server-owned subject/order records.
// Mapping: unknown→auth/anonymous; valid internal path→itself; 401→expire; 403→keep session; policy→401/403/204.
// Side effects: calls the injected loader and mutates local session state; no real user or order is changed.

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

export function createAuthClient(loadSession) {
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
        : Object.freeze({ tag: 'anonymous', reason: 'expired' })
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

  return { bootstrap, expire, state: () => state, sensitiveVisible: () => state.tag === 'authenticated' }
}

export function handleStatus(auth, status, currentPath) {
  if (status === 401) {
    auth.expire()
    return { kind: 'sign-in', returnTo: safeReturnPath(currentPath) }
  }
  if (status === 403) return { kind: 'forbidden' }
  return { kind: 'unchanged' }
}

export function createPolicyServer({ subjects, orders }) {
  return {
    deleteOrder({ subjectId, orderId }) {
      const subject = subjects[subjectId]
      const order = orders[orderId]
      if (!subject) return 401
      if (!order) return 404
      return subject.capabilities.includes('work-order.delete') && subject.tenantId === order.tenantId ? 204 : 403
    },
  }
}
