// Responsibility: own one server query's state, request identity, cancellation, retry, and disposal boundary.
// Data source: normalized query objects and an injected transport returning work-order arrays.
// Mapping: load→loading; latest valid result→success; latest classified failure→error; cancel→idle.
// Side effects: creates AbortController instances and calls transport; stale or disposed work cannot commit.

function normalizeError(cause) {
  if (cause && typeof cause === 'object' && ['http', 'parse', 'network'].includes(cause.kind)) return cause
  return { kind: 'network', message: cause instanceof Error ? cause.message : String(cause) }
}

export function createServerStateController(transport) {
  let state = Object.freeze({ tag: 'idle' })
  let currentRequestId = 0
  let currentController = null
  let lastQuery = null
  let alive = true
  const trace = []

  const commit = (next) => {
    state = Object.freeze(next)
    trace.push(`commit:${next.tag}:${next.requestId ?? '-'}`)
  }

  async function load(query) {
    const requestId = ++currentRequestId
    currentController?.abort('superseded')
    const controller = new AbortController()
    currentController = controller
    lastQuery = Object.freeze({ ...query })
    const previous = state.tag === 'success' ? state.data : undefined
    commit({ tag: 'loading', requestId, query: lastQuery, ...(previous ? { previous } : {}) })
    trace.push(`start:${requestId}:${lastQuery.status}:${lastQuery.page}`)

    const mayCommit = () => alive && requestId === currentRequestId && !controller.signal.aborted
    try {
      const data = await transport({ query: lastQuery, requestId, signal: controller.signal })
      if (!Array.isArray(data)) throw { kind: 'parse', message: 'expected WorkOrder[]' }
      if (mayCommit()) {
        commit({ tag: 'success', requestId, query: lastQuery, data: Object.freeze([...data]) })
      } else {
        trace.push(`discard:success:${requestId}`)
      }
    } catch (cause) {
      if (mayCommit()) {
        commit({ tag: 'error', requestId, query: lastQuery, error: normalizeError(cause), ...(previous ? { previous } : {}) })
      } else {
        trace.push(`discard:error:${requestId}`)
      }
    } finally {
      if (requestId === currentRequestId && currentController === controller) currentController = null
      trace.push(`finally:${requestId}:current=${currentRequestId}`)
    }
  }

  function retry() {
    return lastQuery ? load(lastQuery) : Promise.resolve()
  }

  function cancel() {
    currentController?.abort('user-cancelled')
    currentController = null
    currentRequestId += 1
    commit({ tag: 'idle' })
    trace.push('cancel:current')
  }

  function dispose() {
    alive = false
    currentRequestId += 1
    currentController?.abort('component-unmounted')
    currentController = null
    trace.push('dispose')
  }

  return {
    load,
    retry,
    cancel,
    dispose,
    getState: () => state,
    getTrace: () => [...trace],
    isEmpty: () => state.tag === 'success' && state.data.length === 0,
  }
}
