import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

// Responsibility: apply the public cleanup oracle unchanged to the private correction.
const sourceUrl = new URL('../src/FilterEffects.vue', import.meta.url)
const source = readFileSync(fileURLToPath(sourceUrl), 'utf8')
const acceptsCleanup = /watch\s*\(\s*filter\s*,\s*async\s*\([^)]*onCleanup/.test(source)
const registersAbort = /onCleanup\s*\(\s*\(\)\s*=>\s*controller\.abort\(\)\s*\)/.test(source)
const passesSignal = /signal\s*:\s*controller\.signal/.test(source)

// Mapping: require source, cleanup, and signal to describe one complete resource contract.
if (!acceptsCleanup || !registersAbort || !passesSignal) {
  console.error(`FAIL watcher-cleanup acceptsCleanup=${acceptsCleanup} registersAbort=${registersAbort} passesSignal=${passesSignal}`)
  process.exit(1)
}

console.log('PASS effects-lifecycle private-solution cleanup=registered signal=passed ownership=per-run')

