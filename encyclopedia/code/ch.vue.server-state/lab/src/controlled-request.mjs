// Responsibility: expose request slots so the lab can force success, failure, and out-of-order settlement.
// Data source: request id/query/signal from the repaired controller and explicit lab settlement calls.
// Mapping: one id maps to one Promise slot; abort is recorded but deliberately does not auto-reject.
// Side effects: creates in-memory Promises only; it intentionally ignores abort to stress the identity guard.

export function createControlledRequest() {
  const slots = new Map()
  function request({ query, requestId, signal }) {
    return new Promise((resolve, reject) => {
      slots.set(requestId, { query, signal, resolve, reject })
    })
  }
  return { request, slot: (id) => slots.get(id) }
}
