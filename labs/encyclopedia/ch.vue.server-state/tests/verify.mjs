// Responsibility: verify repaired behavior against three saved faults and the complete async-state matrix.
// Data source: fault-records.json and controlled request slots; no random delay or external service.
// Mapping: explicit settle order maps to expected current tag/request id/trace markers.
// Side effects: reads one local JSON file and prints one deterministic PASS line.

import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { createControlledRequest } from '../src/controlled-request.mjs'
import { createQueryController } from '../src/query-controller.mjs'

const records = JSON.parse(await readFile(new URL('../fault-records.json', import.meta.url), 'utf8'))
assert.deepEqual(records.faults.map((fault) => fault.id), [
  'stale-response-overwrite',
  'loading-state-corruption',
  'post-unmount-update',
])
assert.ok(records.faults.every((fault) => fault.first_evidence.length > 20 && fault.fix.length > 20))
assert.equal(records.same_oracle_rerun, true)
assert.equal(records.real_vue_runtime_recorded, false)
assert.equal(records.real_browser_fetch_recorded, false)
assert.equal(records.real_server_log_recorded, false)

const make = () => {
  const controlled = createControlledRequest()
  return { controlled, controller: createQueryController(controlled.request) }
}

{
  const { controlled, controller } = make()
  const run = controller.load({ status: 'OK', page: 1 })
  controlled.slot(1).resolve([{ id: 'WO-1' }])
  await run
  assert.equal(controller.state().tag, 'success')
}

{
  const { controlled, controller } = make()
  const run = controller.load({ status: 'EMPTY', page: 1 })
  controlled.slot(1).resolve([])
  await run
  assert.deepEqual(controller.state().data, [])
}

for (const fault of [{ kind: 'http', status: 500 }, { kind: 'parse', message: 'bad body' }]) {
  const { controlled, controller } = make()
  const run = controller.load({ status: 'ERROR', page: 1 })
  controlled.slot(1).reject(fault)
  await run
  assert.equal(controller.state().error.kind, fault.kind)
}

{
  const { controlled, controller } = make()
  const first = controller.load({ status: 'RETRY', page: 1 })
  controlled.slot(1).reject({ kind: 'http', status: 503 })
  await first
  const second = controller.retry()
  controlled.slot(2).resolve([{ id: 'WO-RETRY' }])
  await second
  assert.equal(controller.state().requestId, 2)
}

{
  const { controlled, controller } = make()
  const oldRun = controller.load({ status: 'OLD', page: 1 })
  const latestRun = controller.load({ status: 'LATEST', page: 1 })
  controlled.slot(2).resolve([{ id: 'LATEST' }])
  await latestRun
  controlled.slot(1).resolve([{ id: 'STALE' }])
  await oldRun
  assert.equal(controller.state().data[0].id, 'LATEST')
  assert.ok(controller.trace().includes('discard:success:1'))
}

{
  const { controlled, controller } = make()
  const oldRun = controller.load({ status: 'OLD', page: 1 })
  const latestRun = controller.load({ status: 'LATEST', page: 1 })
  controlled.slot(1).reject({ kind: 'network', message: 'old failure' })
  await oldRun
  assert.equal(controller.state().tag, 'loading')
  assert.equal(controller.state().requestId, 2)
  controlled.slot(2).resolve([{ id: 'LATEST' }])
  await latestRun
}

{
  const { controlled, controller } = make()
  const run = controller.load({ status: 'CANCEL', page: 1 })
  controller.cancel()
  controlled.slot(1).resolve([{ id: 'LATE' }])
  await run
  assert.equal(controller.state().tag, 'idle')
}

{
  const { controlled, controller } = make()
  const run = controller.load({ status: 'UNMOUNT', page: 1 })
  controller.dispose()
  controlled.slot(1).resolve([{ id: 'POST-UNMOUNT' }])
  await run
  assert.equal(controller.trace().includes('commit:success:1'), false)
  assert.ok(controller.trace().includes('discard:success:1'))
}

console.log('VUE_SERVER_STATE_LAB_PASS scenarios=9 faults=3 browser-and-server=unverified')
