// Responsibility: own the fixed latest-request-wins and unmount boundary for one server query.
// Data source: normalized query objects and an injected request function.
// Mapping: current id may commit loading/success/error; stale or disposed completions are ignored.
// Side effects: aborts superseded/disposed requests and invokes the injected transport.

export function createQueryController(request) {
  let state = Object.freeze({ tag: 'idle' })
  let currentId = 0
  let currentController = null
  let alive = true

  async function load(query) {
    const requestId = ++currentId
    currentController?.abort('superseded')
    const controller = new AbortController()
    currentController = controller
    state = Object.freeze({ tag: 'loading', requestId, query: Object.freeze({ ...query }) })
    const mayCommit = () => alive && currentId === requestId && !controller.signal.aborted

    try {
      const data = await request({ query, requestId, signal: controller.signal })
      if (!Array.isArray(data)) throw { kind: 'parse', message: 'expected array' }
      if (mayCommit()) state = Object.freeze({ tag: 'success', requestId, query, data: Object.freeze([...data]) })
    } catch (error) {
      if (mayCommit()) state = Object.freeze({ tag: 'error', requestId, query, error })
    } finally {
      if (currentId === requestId && currentController === controller) currentController = null
    }
  }

  function dispose() {
    alive = false
    currentId += 1
    currentController?.abort('component-unmounted')
    currentController = null
  }

  return { load, dispose, state: () => state }
}
