// Responsibility: detect stale overwrite, loading corruption, and post-dispose update in any candidate controller.
// Data source: the exercise controller and deterministic in-memory Promise slots.
// Mapping: three forced settlement orders map to three stable diagnostic messages.
// Side effects: runs local Promises and prints a deterministic red or green contract result.

import { createQueryController } from '../src/query-controller.mjs'

function harness() {
  const slots = new Map()
  const request = ({ query, requestId, signal }) => new Promise((resolve, reject) => {
    slots.set(requestId, { query, signal, resolve, reject })
  })
  return { controller: createQueryController(request), slot: (id) => slots.get(id) }
}

const errors = []

{
  const test = harness()
  const oldRun = test.controller.load({ status: 'OLD', page: 1 })
  const latestRun = test.controller.load({ status: 'LATEST', page: 1 })
  test.slot(2).resolve([{ id: 'WO-LATEST' }])
  await latestRun
  test.slot(1).resolve([{ id: 'WO-STALE' }])
  await oldRun
  if (test.controller.state().data?.[0]?.id !== 'WO-LATEST') {
    errors.push('latest request result was overwritten by stale response')
  }
}

{
  const test = harness()
  const oldRun = test.controller.load({ status: 'OLD', page: 1 })
  const latestRun = test.controller.load({ status: 'LATEST', page: 1 })
  test.slot(1).reject({ kind: 'network', message: 'old failed' })
  await oldRun
  if (test.controller.state().tag !== 'loading' || test.controller.state().requestId !== 2) {
    errors.push('old finally/error cleared or replaced latest loading state')
  }
  test.slot(2).resolve([{ id: 'WO-LATEST' }])
  await latestRun
}

{
  const test = harness()
  const run = test.controller.load({ status: 'UNMOUNT', page: 1 })
  test.controller.dispose()
  test.slot(1).resolve([{ id: 'WO-POST-UNMOUNT' }])
  await run
  if (test.controller.state().tag === 'success') {
    errors.push('disposed controller accepted a late response')
  }
}

if (errors.length > 0) {
  for (const error of errors) console.log(`ERROR: ${error}`)
  console.log(`VUE_SERVER_STATE_EXERCISE=FAIL (${errors.length} violations)`)
  process.exit(1)
}

console.log('VUE_SERVER_STATE_EXERCISE=PASS stale=blocked loading=current dispose=sealed')
