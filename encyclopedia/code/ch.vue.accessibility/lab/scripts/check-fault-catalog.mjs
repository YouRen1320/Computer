import { readFile } from 'node:fs/promises'

// Responsibility: ensure all four diagnostic injections remain explicit and outside the healthy suite.
const immediate = await readFile(new URL('../faults/ImmediateFocus.vue', import.meta.url), 'utf8')
const teleport = await readFile(new URL('../faults/TeleportScopedQuery.test.ts', import.meta.url), 'utf8')
const silent = await readFile(new URL('../faults/SilentErrorDialog.vue', import.meta.url), 'utf8')
const trap = await readFile(new URL('../faults/KeyboardTrapDialog.vue', import.meta.url), 'utf8')
if (immediate.includes('nextTick')) throw new Error('immediate-focus fault accidentally waits')
if (!teleport.includes("wrapper.get('[role=\"dialog\"]')")) throw new Error('Teleport scope fault missing')
if (/role=["']alert/.test(silent) || /aria-live/.test(silent)) throw new Error('silent-error fault accidentally announces')
if (!trap.includes('event.preventDefault()') || trap.includes("event.key === 'Escape'")) throw new Error('keyboard-trap fault missing')
console.log('PASS fault-catalog timing=bad teleport-scope=bad silent-error=bad keyboard-trap=bad')
