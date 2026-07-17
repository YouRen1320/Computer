import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

// Responsibility: require a reactive param source, reload mapping, and initial run in the repair.
const source = readFileSync(fileURLToPath(new URL('../src/WorkOrderDetailPage.vue', import.meta.url)), 'utf8')
const watchesParam = /watch\s*\(\s*\(\)\s*=>\s*route\.params\.workOrderId/.test(source)
const mapsNextParam = /(?:async\s*)?\(?\s*(?:nextId|workOrderId)\s*\)?\s*=>[\s\S]*?loadWorkOrder\s*\(\s*String\s*\(\s*(?:nextId|workOrderId)\s*\)\s*\)/.test(source)
const runsImmediately = /\{\s*immediate\s*:\s*true\s*\}/.test(source)
const avoidsSnapshot = !/const\s+firstId\s*=\s*String\(route\.params\.workOrderId\)/.test(source)

if (!watchesParam || !mapsNextParam || !runsImmediately || !avoidsSnapshot) {
  console.error(`EXPECTED_RED route-param watches=${watchesParam} maps=${mapsNextParam} immediate=${runsImmediately} noSnapshot=${avoidsSnapshot}`)
  console.error('Watch route.params.workOrderId, map each next value to loadWorkOrder, and run immediately.')
  process.exit(1)
}
console.log('PASS router-navigation exercise param=reused-component-refresh')

