import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

// Responsibility: verify per-run abort cleanup without executing learner network code.
const sourceUrl = new URL('../src/FilterEffects.vue', import.meta.url)
const source = readFileSync(fileURLToPath(sourceUrl), 'utf8')
const acceptsCleanup = /watch\s*\(\s*filter\s*,\s*async\s*\([^)]*onCleanup/.test(source)
const registersAbort = /onCleanup\s*\(\s*\(\)\s*=>\s*controller\.abort\(\)\s*\)/.test(source)
const passesSignal = /signal\s*:\s*controller\.signal/.test(source)

// Mapping: all three observable contract pieces are required for one owned cancellable run.
if (!acceptsCleanup || !registersAbort || !passesSignal) {
  console.error(`EXPECTED_RED watcher-cleanup acceptsCleanup=${acceptsCleanup} registersAbort=${registersAbort} passesSignal=${passesSignal}`)
  console.error('Register controller.abort() with this watcher run\'s onCleanup callback.')
  process.exit(1)
}

console.log('PASS effects-lifecycle exercise cleanup=registered signal=passed ownership=per-run')

