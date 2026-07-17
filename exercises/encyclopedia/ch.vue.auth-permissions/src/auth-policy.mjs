// Responsibility: intentionally model broken auth and authorization boundaries for diagnosis practice.
// Data source: untrusted returnTo, injected session responses, and caller-supplied clientAllowed flags.
// Mapping: raw redirects pass through, initial auth is optimistic, and API permission trusts the browser.
// Side effects: mutates only local auth state; the insecure policy fixture performs no real deletion.

export function safeReturnPath(raw) {
  return String(raw)
}

export function createAuthClient(loadSession) {
  let state = { tag: 'authenticated', subject: { id: 'optimistic' }, capabilities: ['work-order.delete'] }

  async function bootstrap() {
    const response = await loadSession()
    state = response.status === 200
      ? { tag: 'authenticated', subject: response.subject, capabilities: response.capabilities }
      : { tag: 'anonymous' }
  }

  function expire() {
    state = { tag: 'anonymous', reason: 'expired' }
  }

  return { bootstrap, expire, state: () => state, sensitiveVisible: () => state.tag === 'authenticated' }
}

export function handleStatus(auth, status) {
  if (status === 401 || status === 403) {
    auth.expire()
    return { kind: 'sign-in' }
  }
  return { kind: 'unchanged' }
}

export function createPolicyServer() {
  return {
    deleteOrder({ clientAllowed }) {
      return clientAllowed ? 204 : 403
    },
  }
}
