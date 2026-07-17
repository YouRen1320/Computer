// Responsibility: grade answer.json against observable offline/idempotency contracts; violations exit nonzero.
import { readFile } from 'node:fs/promises'
const a = JSON.parse(await readFile(new URL('./answer.json', import.meta.url), 'utf8'))
const p = []
if (new Set(a.replayKeys).size !== 1) p.push('stable-key')
if (!Number.isInteger(a.maxAttempts) || a.attemptCount > a.maxAttempts) p.push('retry-budget')
if (!a.nextAttemptAt && a.poisonState !== 'dead-letter') p.push('retry-schedule')
if (a.http401State !== 'blocked-auth') p.push('http401')
if (a.http409State !== 'conflict') p.push('http409')
if (a.poisonState !== 'dead-letter' || !a.independentProcessed) p.push('poison-isolation')
if (!a.ownerMatches && a.sentWhenOwnerMismatched) p.push('owner-boundary')
if (p.length) { console.error(`EXPECTED_UNIAPP_OFFLINE_IDEMPOTENCY_RED problems=${p.join(',')}`); process.exit(1) }
console.log('UNIAPP_OFFLINE_IDEMPOTENCY_EXERCISE_PASS')
