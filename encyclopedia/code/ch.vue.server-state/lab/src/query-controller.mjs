// Responsibility: implement the repaired async query state machine used by the fault lab.
// Data source: normalized query objects and a deterministic injected request function.
// Mapping: current request owns loading/success/error; stale, cancelled, and disposed callbacks are discarded.
// Side effects: creates AbortController objects and invokes the injected request; no real network is used.

export function createQueryController(request) {
  let state = Object.freeze({ tag: 'idle' })
  let currentId = 0
  let controller = null
  let alive = true
  let lastQuery = null
  const trace = []

  const commit = (next) => {
    state = Object.freeze(next)
    trace.push(`commit:${next.tag}:${next.requestId ?? '-'}`)
  }

  async function load(input) {
    const requestId = ++currentId
    controller?.abort('superseded')
    const ownController = new AbortController()
    controller = ownController
    lastQuery = Object.freeze({ ...input })
    commit({ tag: 'loading', requestId, query: lastQuery })
    const current = () => alive && requestId === currentId && !ownController.signal.aborted

    try {
      const data = await request({ query: lastQuery, requestId, signal: ownController.signal })
      if (!Array.isArray(data)) throw { kind: 'parse', message: 'expected array' }
      if (current()) commit({ tag: 'success', requestId, query: lastQuery, data: Object.freeze([...data]) })
      else trace.push(`discard:success:${requestId}`)
    } catch (cause) {
      if (current()) {
        const error = cause && typeof cause === 'object' && cause.kind ? cause : { kind: 'network', message: String(cause) }
        commit({ tag: 'error', requestId, query: lastQuery, error })
      } else trace.push(`discard:error:${requestId}`)
    } finally {
      if (currentId === requestId && controller === ownController) controller = null
      trace.push(`finally:${requestId}:current=${currentId}`)
    }
  }

  const retry = () => (lastQuery ? load(lastQuery) : Promise.resolve())
  const cancel = () => {
    controller?.abort('cancelled')
    controller = null
    currentId += 1
    commit({ tag: 'idle' })
  }
  const dispose = () => {
    alive = false
    currentId += 1
    controller?.abort('unmounted')
    controller = null
    trace.push('dispose')
  }

  return { load, retry, cancel, dispose, state: () => state, trace: () => [...trace] }
}
