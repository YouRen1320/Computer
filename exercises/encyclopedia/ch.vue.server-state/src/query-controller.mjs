// Responsibility: intentionally demonstrate a broken async query owner for diagnosis practice.
// Data source: normalized query objects and an injected controlled request function.
// Mapping: every completion incorrectly writes shared state without checking current request identity.
// Side effects: starts async requests and, by design, permits stale and post-dispose commits.

export function createQueryController(request) {
  let state = { tag: 'idle' }
  let requestId = 0
  let alive = true

  async function load(query) {
    const ownId = ++requestId
    state = { tag: 'loading', requestId: ownId, query }
    try {
      const data = await request({ query, requestId: ownId, signal: new AbortController().signal })
      state = { tag: 'success', requestId: ownId, query, data }
    } catch (error) {
      state = { tag: 'error', requestId: ownId, query, error }
    } finally {
      state.loading = false
    }
  }

  function dispose() {
    alive = false
  }

  return { load, dispose, state: () => state, alive: () => alive }
}
