// Responsibility: verify the canonical success/empty/error/retry/cancel/race/dispose state matrix.
// Data source: deterministic controlled transports; no production API or browser timing.
// Mapping: each scenario settles named request ids and asserts the observable final state/trace.
// Side effects: runs in one Node process and writes only the final PASS line to stdout.

import assert from 'node:assert/strict'
import { createControlledTransport } from '../src/controlled-transport.mjs'
import { createServerStateController } from '../src/server-state-controller.mjs'

const query = (status, page = 1) => ({ status, page })

{
  const controlled = createControlledTransport()
  const controller = createServerStateController(controlled.transport)
  assert.equal(controller.getState().tag, 'idle')
  const run = controller.load(query('ASSIGNED'))
  assert.equal(controller.getState().tag, 'loading')
  controlled.slot(1).resolve([{ id: 'WO-1' }])
  await run
  assert.deepEqual(controller.getState().data, [{ id: 'WO-1' }])
}

{
  const controlled = createControlledTransport()
  const controller = createServerStateController(controlled.transport)
  const run = controller.load(query('EMPTY'))
  controlled.slot(1).resolve([])
  await run
  assert.equal(controller.getState().tag, 'success')
  assert.equal(controller.isEmpty(), true)
}

for (const fault of [
  { kind: 'http', status: 503, message: 'HTTP 503' },
  { kind: 'parse', message: 'invalid JSON shape' },
]) {
  const controlled = createControlledTransport()
  const controller = createServerStateController(controlled.transport)
  const run = controller.load(query('FAULT'))
  controlled.slot(1).reject(fault)
  await run
  assert.equal(controller.getState().tag, 'error')
  assert.equal(controller.getState().error.kind, fault.kind)
}

{
  const controlled = createControlledTransport()
  const controller = createServerStateController(controlled.transport)
  const failed = controller.load(query('RETRY'))
  controlled.slot(1).reject({ kind: 'http', status: 500, message: 'HTTP 500' })
  await failed
  const retried = controller.retry()
  controlled.slot(2).resolve([{ id: 'WO-RETRY' }])
  await retried
  assert.equal(controller.getState().requestId, 2)
  assert.equal(controller.getState().data[0].id, 'WO-RETRY')
}

{
  const controlled = createControlledTransport({ honorAbort: false })
  const controller = createServerStateController(controlled.transport)
  const oldRun = controller.load(query('OLD'))
  const latestRun = controller.load(query('LATEST'))
  controlled.slot(2).resolve([{ id: 'WO-LATEST' }])
  await latestRun
  controlled.slot(1).resolve([{ id: 'WO-STALE' }])
  await oldRun
  assert.equal(controller.getState().data[0].id, 'WO-LATEST')
  assert.ok(controller.getTrace().includes('discard:success:1'))
}

{
  const controlled = createControlledTransport({ honorAbort: false })
  const controller = createServerStateController(controlled.transport)
  const oldRun = controller.load(query('OLD-ERROR'))
  const latestRun = controller.load(query('LATEST-PENDING'))
  controlled.slot(1).reject({ kind: 'network', message: 'old failed' })
  await oldRun
  assert.equal(controller.getState().tag, 'loading')
  assert.equal(controller.getState().requestId, 2)
  controlled.slot(2).resolve([{ id: 'WO-2' }])
  await latestRun
}

{
  const controlled = createControlledTransport({ honorAbort: false })
  const controller = createServerStateController(controlled.transport)
  const run = controller.load(query('CANCEL'))
  controller.cancel()
  controlled.slot(1).resolve([{ id: 'WO-LATE' }])
  await run
  assert.equal(controller.getState().tag, 'idle')
}

{
  const controlled = createControlledTransport({ honorAbort: false })
  const controller = createServerStateController(controlled.transport)
  const run = controller.load(query('UNMOUNT'))
  controller.dispose()
  controlled.slot(1).resolve([{ id: 'WO-POST-UNMOUNT' }])
  await run
  assert.ok(controller.getTrace().includes('dispose'))
  assert.ok(controller.getTrace().includes('discard:success:1'))
  assert.equal(controller.getTrace().some((entry) => entry === 'commit:success:1'), false)
}

console.log('VUE_SERVER_STATE_EXAMPLE_PASS scenarios=9 stale-commit=blocked real-network=unverified')
