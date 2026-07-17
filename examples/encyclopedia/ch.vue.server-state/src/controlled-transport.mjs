// Responsibility: let tests settle each request in a chosen order without clocks or network.
// Data source: controller requestId/query/signal plus explicit resolve/reject calls from the test.
// Mapping: each request becomes one externally controlled pending slot keyed by requestId.
// Side effects: creates Promises and optional abort listeners; no HTTP, timers, files, or global state.

export function createControlledTransport({ honorAbort = false } = {}) {
  const pending = new Map()

  function transport({ query, requestId, signal }) {
    return new Promise((resolve, reject) => {
      const slot = {
        query,
        signal,
        settled: false,
        resolve(value) {
          if (slot.settled) return
          slot.settled = true
          pending.delete(requestId)
          resolve(value)
        },
        reject(error) {
          if (slot.settled) return
          slot.settled = true
          pending.delete(requestId)
          reject(error)
        },
      }
      pending.set(requestId, slot)
      if (honorAbort) {
        signal.addEventListener('abort', () => slot.reject(Object.assign(new Error('aborted'), { name: 'AbortError' })), { once: true })
      }
    })
  }

  return {
    transport,
    slot: (requestId) => pending.get(requestId),
    pendingIds: () => [...pending.keys()],
  }
}
